import shutil
from pathlib import Path
from typing import Union
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from google.cloud import vision
from PIL import Image
import os
from fastapi.responses import FileResponse
from fastapi import Response
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing import image as keras_image
import numpy as np
from datetime import datetime
from fastapi.encoders import jsonable_encoder
from fastapi.staticfiles import StaticFiles

# Initialisation de FastAPI.
app = FastAPI()

app.mount("/tmp/object", StaticFiles(directory="tmp/object"), name="object")


# Charger le modèle
model = load_model('mon_model_mobileNet.h5')

# Autorise toutes les requêtes au serveur uvicorn.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permet les requêtes de toutes les origines.
    allow_credentials=True,
    allow_methods=["*"],  # Permet toutes les méthodes.
    allow_headers=["*"],  # Permet tous les headers.
)

@app.get("/images/{image_path}")
def get_image(image_path: str):

    # Renvoyer l'image en tant que réponse
    return FileResponse(image_path, media_type="image/jpeg")

@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.post("/upload_image")
async def upload_image(response: Response, image: UploadFile = File()):

    content = await image.read(),
    image.file.seek(0)
    save_path = Path("tmp") / image.filename
    with save_path.open("wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    dict_objects = object_detector(save_path)

    return dict_objects

def analyze_image(cropped_img, path):
    # Redimensionne l'image à la taille attendue par le modèle
    resized_img = cropped_img.resize((224, 224))

    # Prépare l'image pour l'analyse
    img_tensor = keras_image.img_to_array(resized_img)  # convertit l'image PIL en np array
    img_tensor = np.expand_dims(img_tensor, axis=0)  # l'image est un vecteur 1D, ajoute une dimension pour créer un lot d'une seule image
    img_tensor /= 255.  # normalise l'image de la même manière que vos données d'entraînement

    # Faites une prédiction avec votre modèle
    predictions = model.predict(img_tensor)

    # Détermine la classe prédite
    predicted_class = np.argmax(predictions)

    # Liste des noms de classe, à personnaliser en fonction de votre modèle
    class_names = ['100e', '10c', '10e', '1c', '1e', '200e', '20c', '20e', '2c', '2e', '500e', '50c', '50e', '5c', '5e', 'cheque']
    print(f"Dans la photo {path} le modèle à trouvé {class_names[predicted_class]}")
    return class_names[predicted_class]

def object_detector(image_path):
    total = 0
    total_banknotes = 0
    count_banknotes = 0
    all_banknotes = {
        "5e": 0,
        "10e": 0,
        "20e": 0,
        "50e": 0,
        "100e": 0,
        "200e": 0,
        "500e": 0
    }
    total_coins = 0
    count_coins = 0
    all_coins = {
        "1c": 0,
        "2c": 0,
        "5c": 0,
        "10c": 0,
        "20c": 0,
        "50c": 0,
        "1e": 0,
        "2e": 0
    }
    total_cheques = "0"
    count_cheques = 0

    dict_objects = {
        "total": total,
        "total_banknotes": total_banknotes,
        "count_banknotes": count_banknotes,
        "all_banknotes": all_banknotes,
        "total_coins": total_coins,
        "count_coins": count_coins,
        "all_coins": all_coins,
        "total_cheques": total_cheques,
        "count_cheques": count_cheques,
        "img_cheques": [],
    }

    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "tmp/concise-atlas-391308-75cb01131c11.json"

    # Créez un client pour l'API Vision
    client = vision.ImageAnnotatorClient()

    # Ouvre l'image
    with open(image_path, 'rb') as image_file:
        content = image_file.read()

    # Construise une instance de l'image à envoyer à l'API
    image = vision.Image(content=content)

    # Effectue une demande d'annotation d'image à l'API
    response = client.object_localization(image=image)

    # Ouvre l'image originale avec PIL
    img = Image.open(image_path)

    # Parcoure les résultats et découpez chaque objet
    for i, object in enumerate(response.localized_object_annotations):
        # print('Nom de l\'objet: {}'.format(object.name))
        # print('Confidence: {}'.format(object.score))

        # Les coordonnées sont relatives à la taille de l'image, donc nous devons les multiplier
        # par la largeur et la hauteur pour obtenir les vraies coordonnées.
        box = [(vertex.x * img.width, vertex.y * img.height)
               for vertex in object.bounding_poly.normalized_vertices]

        # PIL exige que le rectangle de découpage soit sous la forme [gauche, haut, droite, bas]
        # donc nous devons réorganiser les coordonnées
        box = [box[0][0], box[0][1], box[2][0], box[2][1]]

        # Découpe l'image et la sauvegarde
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        cropped_img = img.crop(box)
        cropped_img.save(f'tmp/object/object_{i}_{timestamp}.png', 'PNG')

        # Appelle la fonction d'analyse d'image sur l'image découpée
        analyse = analyze_image(cropped_img, f'tmp/object/object_{i}_{timestamp}.png')


        if analyse in ["5e", "10e", "20e", "50e", "100e", "200e", "500e"]:
            count_banknotes += 1
            total += int(analyse[:len(analyse) - 1])
            total_banknotes += int(analyse[:len(analyse) - 1])
            dict_objects["all_banknotes"][analyse] += 1
        elif analyse in ["1c", "2c", "5c", "10c", "20c", "50c", "1e", "2e"]:
            if analyse == "1c":
                total += 0.01
                total_coins += 0.02
            elif analyse == "2c":
                total += 0.02
                total_coins += 0.02
            elif analyse == "5c":
                total += 0.05
                total_coins += 0.05
            elif analyse == "10c":
                total += 0.1
                total_coins += 0.1
            elif analyse == "20c":
                total += 0.2
                total_coins += 0.2
            elif analyse == "50c":
                total += 0.5
                total_coins += 0.5
            else:
                total += int(analyse[:len(analyse) - 1])
                total_coins += int(analyse[:len(analyse) - 1])
            count_coins += 1
            dict_objects["all_coins"][analyse] += 1
        else:
            count_cheques =+ 1
            dict_objects["img_cheques"].append(f"tmp/object/object_{i}_{timestamp}.png")

    dict_objects["total"] = str(total)
    dict_objects["total_banknotes"] = str(total_banknotes)
    dict_objects["count_banknotes"] = str(count_banknotes)
    dict_objects["total_coins"] = str(total_coins)
    dict_objects["count_coins"] = str(count_coins)
    # response["total_cheques"] = total_cheques
    dict_objects["count_cheques"] = str(count_cheques)
    return dict_objects




    # # TODO: Supprimer les images après analyse
    # os.remove(image_path)