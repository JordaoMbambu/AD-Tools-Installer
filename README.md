# AD-Tools Installer

Script bash d'installation automatique des outils Active Directory référencés dans le module HTB "Active Directory Enumeration & Attacks".

## ⚠️ Avertissement légal

Ce projet est destiné exclusivement à des fins éducatives et de tests d'intrusion **autorisés**. Toute utilisation sur des systèmes sans autorisation écrite préalable est illégale. L'auteur décline toute responsabilité en cas d'utilisation abusive.

## Ce que fait le script

Il installe et organise dans `~/Documents/Programs/AD/` l'ensemble des outils nécessaires pour l'énumération et l'attaque d'environnements Active Directory : outils de reconnaissance, d'exploitation Kerberos, de poisoning réseau, de dump de credentials, d'audit et les PoC des CVE courants.

Les outils sont récupérés selon leur nature via `apt`, `pip3`, `gem`, binaires GitHub ou `git clone`. Les outils Windows uniquement (`setspn.exe`, `AD Explorer`) sont signalés avec leur lien de téléchargement.

## Utilisation

```bash
chmod +x install_ad_tools.sh
sudo ./install_ad_tools.sh
```
