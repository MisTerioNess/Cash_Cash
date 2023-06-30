import shutil
from pathlib import Path
from typing import Union
from fastapi import FastAPI, UploadFile, File
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from google.cloud import vision
from PIL import Image
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permet les requêtes de toutes les origines. Adaptez ceci à vos besoins.
    allow_credentials=True,
    allow_methods=["*"],  # Permet toutes les méthodes. Vous pouvez réduire ceci à ce que vous avez besoin.
    allow_headers=["*"],  # Permet tous les headers. Vous pouvez réduire ceci à ce que vous avez besoin.
)


class Item(BaseModel):
    name: str
    price: float
    is_offer: Union[bool, None] = None


@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.post("/image")
async def upload_image(image: UploadFile = File()):
    content = await image.read(),
    print(image.filename)
    image.file.seek(0)
    save_path = Path("tmp") / image.filename
    with save_path.open("wb") as buffer:
        shutil.copyfileobj(image.file, buffer)
    object_detector(save_path)
    return {"n'importe quoi"}


def object_detector(image_path):
    # # Assurez-vous que votre clé d'authentification est dans votre environnement
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "tmp/concise-atlas-391308-75cb01131c11.json"

    # # Créez un client pour l'API Vision
    client = vision.ImageAnnotatorClient()

    # # Ouvrez l'image et lisez-la dans un tableau d'octets
    with open(image_path, 'rb') as image_file:
        content = image_file.read()

    # # Construisez une instance de l'image à envoyer à l'API
    image = vision.Image(content=content)

    # # Effectuez une demande d'annotation d'image à l'API
    response = client.object_localization(image=image)

    # Parcourez les résultats et affichez les objets trouvés
    # for object in response.localized_object_annotations:
    #     print(object)
    #     print('Nom de l\'objet: {}'.format(object.name))
    #     print('Confidence: {}'.format(object.score))

    # Ouvrez l'image originale avec PIL
    img = Image.open(image_path)

    # Parcourez les résultats et découpez chaque objet
    for i, object in enumerate(response.localized_object_annotations):
        print('Nom de l\'objet: {}'.format(object.name))
        print('Confidence: {}'.format(object.score))

        # Les coordonnées sont relatives à la taille de l'image, donc nous devons les multiplier
        # par la largeur et la hauteur pour obtenir les vraies coordonnées.
        box = [(vertex.x * img.width, vertex.y * img.height)
               for vertex in object.bounding_poly.normalized_vertices]

        # PIL exige que le rectangle de découpage soit sous la forme [gauche, haut, droite, bas]
        # donc nous devons réorganiser les coordonnées
        box = [box[0][0], box[0][1], box[2][0], box[2][1]]

        # Découpez l'image et sauvegardez-la
        cropped_img = img.crop(box)
        cropped_img.save(f'tmp/objects/object_{i}.png')
