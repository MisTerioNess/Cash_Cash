import shutil
from pathlib import Path
from typing import Union
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from google.cloud import vision
from PIL import Image, ImageDraw
import os
from fastapi.responses import FileResponse
from fastapi import Response
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing import image as keras_image
import numpy as np
from datetime import datetime
from fastapi.encoders import jsonable_encoder
from fastapi.staticfiles import StaticFiles
import imghdr
import cv2
import pytesseract
import re
import matplotlib.pyplot as plt

# Initialisation de FastAPI.
app = FastAPI()

app.mount("/image_file/object_detected", StaticFiles(directory="image_file/object_detected"), name="object_detected")
app.mount("/image_file", StaticFiles(directory="image_file"), name="image_file")
app.mount("/image_file/web", StaticFiles(directory="image_file/web"), name="image_file")

# Charger le modèle
model = load_model('model/Ely.h5')

# Autorise toutes les requêtes au serveur uvicorn.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permet les requêtes de toutes les origines.
    allow_credentials=True,
    allow_methods=["*"],  # Permet toutes les méthodes.
    allow_headers=["*"],  # Permet tous les headers.
)

# region COMMUN
def process_image(img_pil, crop_area=None, resize_dims=None):
    """
    Traitement d'image pour améliorer la reconnaissance d'objet avec le modèle Google Vision.

    Args:
    img_pil (PIL.Image): Image à traiter.
    crop_area (tuple, optional): Zone de rognage spécifiée comme un tuple (y1, y2, x1, x2). Par défaut à None.
    resize_dims (tuple, optional): Dimensions de redimensionnement spécifiées comme un tuple (largeur, hauteur). Par défaut à None.

    Returns:
    str: Chemin du fichier de l'image traitée sauvegardée.
    """
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")

    # Convertir l'image PIL en tableau numpy
    img = np.array(img_pil)

    # Appliquer un flou pour réduire la netteté des motifs
    img_output = cv2.GaussianBlur(img, (15, 15), 0)

    # Enregistrer l'image originale
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    cv2.imwrite(f"image_file/original/image_file-{timestamp}.png", img)

    # Enregistrer l'image de contour
    cv2.imwrite(f"image_file/edge/image_file-{timestamp}.png", img_output)

    # img_pil.save(f"image_file/edge/image_file-{timestamp}.png")
    return f"image_file/edge/image_file-{timestamp}.png"

def get_cheque_amout(path):
    """
    Détecte le montant dans le fichier image donné.

    Paramètres:
        path (str): Le chemin vers le fichier image.

    Renvoie:
        list: Une liste des montants détectés dans l'image. 
    """
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "concise-atlas-391308-75cb01131c11.json"
    client = vision.ImageAnnotatorClient()

    with open(path, 'rb') as image_file:
        content = image_file.read()

    image = vision.Image(content=content)
    response = client.text_detection(image=image)
    texts = response.text_annotations

    # Expression régulière pour capturer les montants d'argent.
    money_pattern = re.compile(r'\d+,\d{2}')

    amounts = []

    print('Texts:')
    for text in texts:
        if '€' in text.description:
            text.description = text.description.replace('€', '').replace(' ', '')
        for match in re.finditer(money_pattern, text.description):
            amounts.append(match.group(0))

    if response.error.message:
        raise Exception(
            '{}\nFor more info on error messages, check: '
            'https://cloud.google.com/apis/design/errors'.format(
                response.error.message))
    
    if len(amounts) > 0:
        return amounts[0]
    else:
        return 0

def initialize_object_dict():
    """
    Initialisation du dictionnaire des objets avec les valeurs de départ
    """
    total, total_banknotes, count_banknotes, total_coins, count_coins = 0, 0, 0, 0, 0
    all_banknotes = {"5e": 0, "10e": 0, "20e": 0, "50e": 0, "100e": 0, "200e": 0, "500e": 0}
    all_coins = {"1c": 0, "2c": 0, "5c": 0, "10c": 0, "20c": 0, "50c": 0, "1e": 0, "2e": 0}
    total_cheques, count_cheques = 0, 0

    return {
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
        "img": [],
    }

def process_object(dict_objects, analyse, i, path):
    """
    Traitement des objets détectés et mise à jour des compteurs.

    Args:
        dict_objects (dict): Le dictionnaire contenant les informations sur les objets détectés.
        analyse (str): Le résultat de l'analyse de l'image découpée, indiquant quel type d'objet a été détecté.
        i (int): L'index de l'objet dans la liste des objets détectés.

    Returns:
        dict: Le dictionnaire mis à jour avec les informations sur les objets détectés.
    """
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    if analyse in dict_objects["all_banknotes"]:
        dict_objects["count_banknotes"] += 1
        dict_objects["total"] += int(analyse[:-1])
        dict_objects["total_banknotes"] += int(analyse[:-1])
        dict_objects["all_banknotes"][analyse] += 1
    elif analyse in dict_objects["all_coins"]:
        dict_objects["count_coins"] += 1
        dict_objects["all_coins"][analyse] += 1
        if analyse == "1c" or analyse == "2c" or analyse == "5c":
            analyse = "0" + analyse
        if "e" in analyse:
            dict_objects["total_coins"] += int(analyse[:len(analyse) - 1])
            dict_objects["total"] += int(analyse[:len(analyse) - 1])
        else:
            dict_objects["total_coins"] += float(f"0.{analyse[:len(analyse) - 1]}")
            dict_objects["total"] += float(f"0.{analyse[:len(analyse) - 1]}")
    else:
        dict_objects["count_cheques"] += 1
        dict_objects["img_cheques"].append(path)
        amount = get_cheque_amout(path)
        if amount:
            amount = float(amount.replace(',', '.'))  # Remplacez la virgule par un point et convertissez en float
            dict_objects["total_cheques"] += amount
            dict_objects["total"] += amount
    return dict_objects

@app.get("/images/{image_path}")
def get_image(image_path: str):
    """
    Récupère et retourne une image spécifiée par le chemin d'accès à l'image.

    Args:
        image_path (str): Le chemin d'accès à l'image demandée.

    Returns:
        FileResponse: L'image demandée.
    """
    # Vérifie que le fichier existe et qu'il s'agit d'une image
    if not Path(image_path).is_file() or not imghdr.what(image_path):
        raise HTTPException(status_code=404, detail="Image not found")
    
    # Renvoyer l'image en tant que réponse
    return FileResponse(image_path)

def save_image(img: Image, dict_objects):
    """
    Cette fonction prend une image et un dictionnaire en entrée, sauvegarde l'image dans un répertoire temporaire 
    avec un timestamp dans le nom du fichier, puis retourne le chemin du fichier de l'image et le dictionnaire en entrée.

    Args:
        img (Image): L'image à sauvegarder.
        dict_objects (dict): Dictionnaire d'objets à retourner avec le chemin de l'image.

    Returns:
        Dict: Dictionnaire d'objets en entrée.

    """
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    
    # Crée le dossier image_file s'il n'existe pas.
    if not os.path.exists('image_file'):
        os.makedirs('image_file/web')
    
    file_path = f"image_file/web/imageweb-{timestamp}.png"
    # Sauvegarde de l'image en format JPEG avec une qualité de 85 pour optimiser la taille du fichier.
    img.save(file_path, format="PNG")
    
    # Ajoute le chemin de l'image dans le dictionnaire.
    dict_objects["img"] = file_path
    
    # Renvoi de l'image encadrée en tant que réponse.
    return dict_objects
# endregion

# region MOBILE
@app.post("/upload_image")
async def upload_image(response: Response, image: UploadFile = File()):
    """
    Reçoit une image, la sauvegarde localement, puis exécute la détection d'objets dessus.

    Args:
        response (Response): Objet de réponse Starlette.
        image (UploadFile, optional): Image envoyée dans la requête.

    Returns:
        dict: Dictionnaire contenant les résultats de la détection d'objets.
    """
    # Lire le contenu du fichier
    content = await image.read()

    # Réinitialiser le pointeur du fichier
    image.file.seek(0)

    # Définir le chemin où l'image sera sauvegardée
    save_path = Path("image_file") / image.filename

    # Ouvrir le fichier en mode écriture binaire et y copier le contenu de l'image
    with save_path.open("wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    # Exécute la détection d'objets sur l'image
    dict_objects = object_detector(save_path)

    return dict_objects

def analyze_image(cropped_img, path):
    """
    Analyse une image découpée et prédit la classe de l'objet dans l'image.

    Args:
        cropped_img (PIL.Image.Image): Image découpée à analyser.
        path (str): Chemin de l'image découpée.

    Returns:
        str: Classe de l'objet prédite.
    """
    # Redimensionne l'image à la taille attendue par le modèle
    resized_img = cropped_img.resize((224, 224))

    # Convertit l'image en tableau numpy, ajoute une dimension pour créer un lot d'une seule image
    # et normalise l'image
    img_tensor = keras_image.img_to_array(resized_img)  
    img_tensor = np.expand_dims(img_tensor, axis=0)
    img_tensor /= 255.

    # Fait une prédiction avec le modèle
    try:
        predictions = model.predict(img_tensor)
        # Détermine la classe prédite
        predicted_class = np.argmax(predictions)
        # Liste des noms de classe, à personnaliser en fonction de votre modèle
        class_names = ['100e', '10c', '10e', '1c', '1e', '200e', '20c', '20e', '2c', '2e', '500e', '50c', '50e', '5c', '5e', 'cheque']
        print(f"Dans la photo {path}, le modèle a trouvé {class_names[predicted_class]}")

        return class_names[predicted_class]
    except:
        return None

def object_detector(image_path):
    """
    Détecte les objets dans l'image donnée, les découpe, analyse chaque découpe, 
    puis met à jour et renvoie un dictionnaire avec les statistiques de détection.
    
    Args:
        image_path (str): Chemin vers l'image à analyser.

    Returns:
        dict: Dictionnaire contenant les statistiques des objets détectés.
    """
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    procesed_img = process_image(img)
    dict_objects = initialize_object_dict()

    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "concise-atlas-391308-75cb01131c11.json"

    client = vision.ImageAnnotatorClient()

    with open(procesed_img, 'rb') as image_file:
        content = image_file.read()

    image = vision.Image(content=content)

    response = client.object_localization(image=image)

    for i, object in enumerate(response.localized_object_annotations):
        box = [(vertex.x * img.width, vertex.y * img.height)
               for vertex in object.bounding_poly.normalized_vertices]
        box = [box[0][0], box[0][1], box[2][0], box[2][1]]
        draw.rectangle(box, outline="green", width=5)

        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        cropped_img = img.crop(box)
        cropped_img.save(f'image_file/object_detected/object_{i}_{timestamp}.png', 'PNG')

        analyse = analyze_image(cropped_img, f'image_file/object_detected/object_{i}_{timestamp}.png')

        dict_objects = process_object(dict_objects, analyse, i,  f'image_file/object_detected/object_{i}_{timestamp}.png')

    dict_objects["total"] = str(round(dict_objects["total"], 2))
    dict_objects["total_banknotes"] = str(round(dict_objects["total_banknotes"], 2))
    dict_objects["count_banknotes"] = str(dict_objects["count_banknotes"])
    dict_objects["total_coins"] = str(round(dict_objects["total_coins"], 2))
    dict_objects["count_coins"] = str(dict_objects["count_coins"])
    dict_objects["count_cheques"] = str(dict_objects["count_cheques"])
    dict_objects["total_cheques"] = str(round(dict_objects["total_cheques"], 2))

    dict_objects = save_image(img, dict_objects)

    return dict_objects
# endregion


# region WEB
@app.post("/upload_image_web")
async def upload_image(image: UploadFile = File()):
    """
    Endpoint pour uploader une image et appeler la fonction object_detector_web.

    Args:
        image (starlette.datastructures.UploadFile, optional): Image à uploader. 
        Defaults to File().

    Returns:
        dict: Renvoie le résultat de la fonction object_detector_web.
    """
    try:
        # Réinitialise le curseur du fichier à la position 0
        image.file.seek(0)
        save_path = Path("image_file") / image.filename

        # Enregistre le fichier uploadé dans le chemin spécifié
        with save_path.open("wb") as buffer:
            shutil.copyfileobj(image.file, buffer)

        # Appelle la fonction object_detector_web avec le chemin du fichier sauvegardé
        return object_detector_web(save_path)
    except Exception as e:
        # En cas d'erreur, renvoie le message d'erreur
        return {"error": str(e)}

def object_detector_web(image_path):
    """
    Cette fonction analyse une image pour y détecter des objets, les découpe et sauvegarde chaque objet détecté dans un fichier séparé.
    Elle met à jour un dictionnaire pour compter le nombre de chaque type d'objet détecté.

    Args:
        image_path (str): Le chemin vers l'image à analyser.

    Returns:
        function: Appel à la fonction encadre_image() avec l'image et le dictionnaire des objets détectés.
    """
    img = Image.open(image_path)
    draw = ImageDraw.Draw(img)
    procesed_img = process_image(img)
    dict_objects = initialize_object_dict()

    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "concise-atlas-391308-75cb01131c11.json"
    client = vision.ImageAnnotatorClient()

    with open(procesed_img, 'rb') as image_file:
        content = image_file.read()

    image = vision.Image(content=content)
    response = client.object_localization(image=image)

    for i, object in enumerate(response.localized_object_annotations):
        draw = ImageDraw.Draw(img)
        box = [(vertex.x * img.width, vertex.y * img.height)
               for vertex in object.bounding_poly.normalized_vertices]
        box = [box[0][0], box[0][1], box[2][0], box[2][1]]

        draw.rectangle(box, outline="green", width=5)

        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")

        cropped_img = img.crop(box)
        cropped_img.save(f'image_file/object_detected/object_{i}_{timestamp}.png', 'PNG')

        analyse = analyze_image(cropped_img, f'image_file/object_detected/object_{i}_{timestamp}.png')

        dict_objects = process_object(dict_objects, analyse, i, f'image_file/object_detected/object_{i}_{timestamp}.png')
    
    dict_objects["total"] = str(round(dict_objects["total"], 2))
    dict_objects["total_banknotes"] = str(round(dict_objects["total_banknotes"], 2))
    dict_objects["count_banknotes"] = str(dict_objects["count_banknotes"])
    dict_objects["total_coins"] = str(round(dict_objects["total_coins"], 2))
    dict_objects["count_coins"] = str(dict_objects["count_coins"])
    dict_objects["count_cheques"] = str(dict_objects["count_cheques"])
    dict_objects["total_cheques"] = str(round(dict_objects["total_cheques"], 2))

    dict_objects = save_image(img, dict_objects)
    return dict_objects
# endregion