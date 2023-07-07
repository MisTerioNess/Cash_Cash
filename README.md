# cash_cash

Projet pour la soutenance L3 E3IN 2023.

Application web et mobile de reconnaissance de:
- chèques
- billets
- pièces de monnaie

## Pour commencer 

Installer flutter :
- [Installation de flutter](https://docs.flutter.dev/get-started/install)
- [Flutter documentation](https://docs.flutter.dev/)

Installer Dart :
- [Installation de Dart](https://dart.dev/get-dart)
- [Dart documentation](https://dart.dev/guides)
    
# Installation
Ouvrir un terminal.

Télécharger le projet.
```console
git clone git@github.com:MisTerioNess/Cash_Cash.git
```

Se mettre dans le dossier du projet.
```console
cd Cash_Cash
```

Installation des dépendances.
```console
flutter pub get
```
# Mise à jour SDK environnement 
Pour procéder à la mise à jour de SDK, suivez les étapes suivantes : 
- ouvrir le terminal de l'IDE
- saisir les commandes suivantes 
```console 
flutter channel beta 
flutter upgrade
flutter channel stable
flutter upgrade --force  
```

# Utiliser un téléphone physique

## Android

- sur votre téléphone 
il faut activer le mode développeur en cliquant plusieurs fois sur le numéro de série puis
en cherchant les options de développeurs vous activez le mode développeur et le débogage USB
[documentation](https://developer.android.com/studio/debug/dev-options?hl=fr)
- sur votre ordinateur
il faut installer le pilote OEM de la marque du téléphone utilisé via ce lien:
[pilote OEM](https://developer.android.com/studio/run/oem-usb?hl=fr#Drivers)

Enfin il faut brancher le téléphone à l'ordinateur via USB et autoriser le débogage USB lorsque
la pop-up apparaitra. 
Dès lors que ceci est fait vous aurez le nom du modèle de votre téléphone dans la sélection des appareils de Android Studio.

## IOS (WIP)

# Analyse métrique avec SonarQube
[extrait de ce tutoriel](https://docs.sonarqube.org/latest/try-out-sonarqube/)

## 1. SonarQube

### 1.1 Installation

Tout d'abord veuillez vérifier que vous avez téléchargé et installé [Java dev kit 17](https://adoptium.net/en-GB/temurin/releases/?version=17)

ensuite vous aurez besoin de l'inscrire en tant que variable d'environnement pour sonarQube, pour ce faire:

- taper dans votre barre de recherche windows "environnement"
- cliquer sur "Modifier les variables d'environnement système"
- en bas à droite de la fenêtre nouvellement apparu vous avez "Variables d'environnement...", cliquer dessus
- dans la partie "variables utilisateur pour *votre nom d'utilisateur*" cliquer sur "Nouvelle..."
- le nom de la variable sera "SONAR_JAVA_PATH" et la valeur sera le chemin d'accès du dossier /bin du java development kit 17 télécharger précedemment

Pour vérifier que la variable d'environnement fonctionne correctement vous pouvez taper dans un nouveau terminal: ``java --version`` . si vous voyez du rouge, ça n'a pas fonctionner ou vous n'avez pas utiliser un nouveau terminal sinon
vous devriez alors voir quelque chose comme:
```
java 20.0.1 2023-04-18
Java(TM) SE Runtime Environment (build 20.0.1+9-29)
Java HotSpot(TM) 64-Bit Server VM (build 20.0.1+9-29, mixed mode, sharing)
```

Ensuite vous pouvez télécharger et installé [sonarQube community edition](https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.1.0.73491.zip).

Enfin, rentrer dans le dossier bin de sonarQube, cliquer sur le dossier windows et lancer StartSonar.bat dans un terminal (.\StartSonar.bat ou taper Star puis sur votre touche tab pour qu'il rentre automatiquement la commande à executer).

Une fois que vous verrez `SonarQube is operational` vous pourrez rejoindre le lien [localhost:9000](http://localhost:9000/).
les nom d'utilisateur et mot de passe par défaut sont: admin et admin.

### 1.2 Configuration

Vous créerez un nouveau projet avec comme clé de projet:Cash_Cash, nom de projet:Cash Cash et "Main branch name": master .

Ensuite après avoir appuyer sur next, sélectionner "Define a specific setting for this project" puis "Number of days" puis dans le champ "Specify a number of days" mettez 1.

Enfin cliquer sur "create project".

Vous serez alors redirigez vers l'onglet Overview de votre projet. On s'arrête la et passons directement à la suite.

## 2. Scanner sonarQube + plugin flutter/dart

Tout d'abord assurer d'avoir le fichier `sonar-project.properties` à la racine de votre projet flutter. Sinon faites git pull pour le récupérer.
Ensuite télécharger [sonar-scanner](https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856-windows.zip) et extrayer le dossier du scanner à l'emplacement que vous souhaitez.

ensuite vous aurez besoin de l'inscrire en tant que variable d'environnement système, pour ce faire:

- taper dans votre barre de recherche windows "environnement"
- cliquer sur "Modifier les variables d'environnement système"
- en bas à droite de la fenêtre nouvellement apparu vous avez "Variables d'environnement...", cliquer dessus
- dans la partie "variables systèmes", chercher la variable `Path`, cliquer dessus et enfin cliquer sur le bouton "Modifier..."
- enfin cliquer sur "Nouveau" en haut à droite et coller le chemin d'accès du dossier /bin du sonar-scanner.

Pour vérifier que la variable d'environnement fonctionne correctement vous pouvez taper `sonar-scanner`, si vous voyez du rouge, ça n'a pas fonctionner ou vous n'avez pas utiliser un nouveau terminal. Si vous voyez plusieurs messages préfixé par le mot "INFO" c'est bon.

Enfin vous pourrez installer l'extension flutter, pour ce faire, télécharger le
[plugin flutter/dart](https://github.com/insideapp-oss/sonar-flutter/releases/tag/0.5.0)
ensuite aller dans votre dossier sonarQube puis dans le dossier extensions puis dans le dossier plugins et glisser le .jar que vous venez de télécharger. Pour que l'extension fonctionne il faudra redémarrer sonarQube. SonarQube vous informera dès l'entrée sur l'URL [localhost:9000](http://localhost:9000/) que l'extension a bien été installé et que vous êtes seuls responsable des éventuelles répercussions de cette extension.

Nous pouvons désormais passer à la suite.

# 3. Scanner votre projet

Enfin, retourner sur [sonarQube localhost:9000](http://localhost:9000) et sélectionner Locally puis générer votre token qui expire dans 30 jours, il vous génèrera un token qui ressemblera à ça: ``sqp_12af240adac9454aca4fe1a4a85db7e84a6c5efd``, noter le quelque part, par exemple dans le dossier bin de sonarQube puis enfin cliquer sur continuer.

Dans l'onglet ``2 Run analysis on your project``:

Sélectionner ``Other (for JS, TS, GO, python, PHP, ...)`` et ``Windows``

Enfin (le vrai enfin), copier la ligne fourni dans la section ``Execute the Scanner`` et qui commence par ``sonar-scanner.bat ...`` et coller-le dans le terminal d'Android Studio et attendez le message qui devrait ressembler à ceci :

``INFO: ANALYSIS SUCCESSFUL, you can find the results at: http://localhost:9000/dashboard?id=Cash_Cash``

🥳🥳🥳🥳

# Source

[object detection](https://pub.dev/packages/google_mlkit_object_detection),
[text_recognition](https://pub.dev/packages/google_mlkit_text_recognition),
[permissions](https://developer.android.com/training/permissions/declaring?hl=fr),
[camera](https://github.com/googlesamples/mlkit/tree/master/android/vision-quickstart)
