# Instructions — PROJET FINAL DEVOPS

Ce fichier contient les consignes du TP et le plan d'action à suivre **avant** de commencer le travail.

## Récapitulatif des consignes principales

- Partie 1 — Site vitrine (Flask)
  - Conteneuriser l'application Flask fournie.
  - Dockerfile : base `python:3.6-alpine`, `WORKDIR /opt`, `pip install Flask`, `EXPOSE 8080`, définir les variables d'environnement `ODOO_URL` et `PGADMIN_URL`, `ENTRYPOINT ["python","app.py"]`.
  - Nom image : `ic-webapp`, tag `1.0`. Container test : `test-ic-webapp`.

- Partie 2 — CI/CD (Jenkins + Ansible)
  - Créer `releases.txt` à la racine contenant : ODOO_URL, PGADMIN_URL, Version (format 3 lignes × 2 colonnes séparées par un espace).
  - Adapter le `Dockerfile` pour lire `releases.txt` au build (usage d'`awk`/`export`) et utiliser `Version` comme tag.
  - Créer deux docker-compose templates : un pour Odoo (+ Postgres) et un pour pgAdmin (avec volume persistant et `/pgadmin4/servers.json`).
  - Créer deux rôles Ansible `odoo_role` et `pgadmin_role` pour déployer les docker-compose ; rendre variables : noms de réseau, volume, chemins de montage, noms de services/containers.
  - Écrire un `Jenkinsfile` qui : checkout → build (tag depuis `releases.txt`) → tests smoke → push vers Docker Hub → deploy via Ansible roles.

- Partie 3 — Kubernetes (Minikube)
  - Créer manifests Kubernetes pour Odoo, Postgres et pgAdmin.
  - Utiliser le namespace `icgroup` et ajouter le label `env=prod` à toutes les ressources.
  - Assurer persistance via PV/PVC pour les bases de données et pgAdmin.

## Fichier `servers.json` pgAdmin
- Préparer un `servers.json` qui pré-configure la connexion à la base Odoo et le monter dans le container pgAdmin (`/pgadmin4/servers.json`).

## Plan d'action (ordre recommandé)
1. Créer ce fichier d'instructions (`instruction.md`).
2. Ajouter le `Dockerfile` de l'application Flask (`Docker_TP/Dockerfile` ou à la racine du module web).
3. Builder et tester l'image `ic-webapp:1.0` localement.
4. Ajouter `releases.txt` et adapter le Dockerfile pour la lecture au build.
5. Créer `docker-compose.odoo.yml` et `docker-compose.pgadmin.yml` (templates variables).
6. Créer les rôles Ansible `odoo_role` et `pgadmin_role`.
7. Écrire le `Jenkinsfile` pour CI/CD.
8. Créer `servers.json` et monter dans pgAdmin.
9. Rédiger manifests Kubernetes et tests de déploiement.
10. Documenter le tout dans un `README.md` de test et déploiement.

## Notes et bonnes pratiques
- Ne pas committer d'informations sensibles (mots de passe, tokens). Utiliser des variables d'environnement/credentials Jenkins/Ansible Vault.
- Tester chaque étape localement (docker build/run, ansible-playbook --check, kubectl apply --dry-run=client).
- Capturer des screenshots et logs pour le rapport final.

---

Si ce contenu vous convient, je commence par créer le `Dockerfile` pour la webapp. Indiquez si vous préférez un autre nom ou emplacement pour ce fichier d'instruction.
