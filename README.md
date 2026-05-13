# printmate spr26-Team-20

Read about us in our [printmate Wiki](https://github.com/StanfordCS194/spr26-Team-20/wiki)

# Team Members
* Felipe Bigolin Groff
* Niklas Vainio
* Carlos Hernandez-Meza
* (others will add their names here when they do the git assignment)


# Running App

## Prerequisites
1. If you haven't installed Flutter yet:
```bash
brew install --cask flutter
flutter doctor
```

2. Connect to Firebase database:
2.1. Get the service account key from Firebase Console:
- Go to Firebase Console
- Select project printimate-44033
- Click ⚙️ (Settings) → Service Accounts
- Click Generate New Private Key
- Save the JSON file

2.2. Create the env directory:
```bash
mkdir -p server/env
```
2.3. Add the .json file dowloaded to server/env


## 1. Start the server
```bash
cd server
npm run dev
```

## 2. Start the app
In a separate terminal:
```bash
cd printmate_app
flutter run -d chrome
```

## 3. Test the API
Once logged in, fetch messages for a printer at:

[http://localhost:3000/messages?pid=printer1](http://localhost:3000/messages?pid=printer1)

Server at port 3000:
[http://localhost:3000](http://localhost:3000)
or
[http://{ip}:3000](http://{ip}:3000)

# Testing info
Name of our printers:
```bash
printer1
```
```bash
printer2
```
