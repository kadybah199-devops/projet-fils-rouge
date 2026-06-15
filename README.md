# PROJET-FILS-ROUGE — Guide rapide

Résumé et étapes pour tester et déployer l'application vitrine (Flask), pgAdmin et Odoo.

## Structure importante
- `app.py` — application Flask (écoute sur le port `8080`).
- `Dockerfile` — construit l'image `ic-webapp` en lisant `releases.txt`.
- `releases.txt` — contient `ODOO_URL`, `PGADMIN_URL`, `VERSION`.
- `entrypoint.sh` — script d'exécution du conteneur web.
- `docker-compose.odoo.yml` — template local pour Odoo + Postgres.
- `docker-compose.pgadmin.yml` — template local pour pgAdmin (monte `pgadmin/servers.json`).
- `ansible/` — playbooks et rôles `odoo_role`, `pgadmin_role`.
- `Jenkinsfile` — pipeline CI/CD (build, push, smoke test, deploy via Ansible).

## Quick start — build et test local de la webapp

1. Build de l'image (tag depuis `releases.txt`):

```bash
cd projet-fils-rouge
docker build -t ic-webapp:1.0 .
```

2. Lancer un container test en fournissant les URLs:

```bash
docker run --rm -d --name test-ic-webapp -p 8080:8080 \
  -e ODOO_URL=https://www.odoo.com -e PGADMIN_URL=https://www.pgadmin.org \
  ic-webapp:1.0

# vérifier
curl -fsS http://localhost:8080/ || docker logs test-ic-webapp
docker stop test-ic-webapp
```

## Tester avec Docker Compose (Odoo + Postgres)

```bash
cd projet-fils-rouge
docker-compose -f docker-compose.odoo.yml up -d
# accéder à Odoo sur http://localhost:8069
```

## Tester pgAdmin (compose)

```bash
cd projet-fils-rouge
docker-compose -f docker-compose.pgadmin.yml up -d
# pgAdmin disponible sur http://localhost:5050 (par défaut)
```

## Ansible — déploiement

Le playbook principal est `ansible/deploy.yml`. Les rôles `odoo_role` et `pgadmin_role` génèrent des fichiers `docker-compose` depuis des templates et lancent `docker-compose up -d`.

Exemple d'exécution locale (inventaire `ansible/inventory.ini` doit être adapté):

```bash
cd projet-fils-rouge/ansible
ansible-playbook -i inventory.ini deploy.yml --private-key /path/to/key -e "web_image=kady199/ic-webapp:1.0"
```

## Jenkins — notes

- Le `Jenkinsfile` lit `releases.txt`, construit et pousse l'image vers Docker Hub, exécute un test smoke et lance `ansible-playbook`.
- Credentials requis dans Jenkins: Docker Hub username/password (`kady199-dockerhub`), clé SSH Ansible (`ansible-ssh-key`) et `github-token` pour push.

## Kubernetes — rappel

Manifests Kubernetes (namespace `icgroup`, label `env=prod`, PV/PVC) ne sont pas encore fournis. Prévoir :
- `namespace/icgroup.yaml`
- `deployment/service` pour Odoo, Postgres, pgAdmin
- `pv`/`pvc` pour persistance

## Fichiers ajoutés/modifiés par moi
- `instruction.md` — consignes et plan (racine workspace).
- `pgadmin/servers.json` — configuration pour auto-enregistrer la connexion Odoo (monté par `docker-compose.pgadmin.yml`).
- `docker-compose.odoo.yml` and `docker-compose.pgadmin.yml` — templates de test local.
- `ansible/roles/pgadmin_role` template updated to optionally mount `servers.json`.

## État d'avancement (point actuel)
- ✅ `app.py`, `Dockerfile`, `entrypoint.sh`, `releases.txt`, `Jenkinsfile` — présents et opérationnels.
- ✅ Rôles Ansible `odoo_role` et `pgadmin_role` — structure et templates en place; `pgadmin_role` mis à jour pour `servers.json`.
- ✅ `docker-compose` templates et `pgadmin/servers.json` — ajoutés pour tests locaux.
- ⬜ Kubernetes manifests — à créer.
- ⬜ Vérification complète des rôles Ansible sur hôtes distants et tests d'intégration.
- ⬜ Mise en place des credentials Jenkins & tests CI complets.

## Prochaines actions recommandées
1. Executer localement le build et le test de l'image (`docker build` + `docker run`).
2. Tester `docker-compose.odoo.yml` et `docker-compose.pgadmin.yml`.
3. Exécuter les rôles Ansible sur une machine de test (ajuster `inventory.ini`).
4. Créer manifests Kubernetes dans `k8s/` et ajouter scripts `kubectl apply`.

---

Si vous voulez, je lance maintenant le build local de l'image `ic-webapp:1.0` et le test smoke. Indiquez si je dois continuer.

## Commandes pas-à-pas (du début à la fin)
Les commandes ci-dessous couvrent l'ensemble du workflow : build, test, push, déploiement via Docker Compose/Ansible, et étapes K8s.

Prérequis : `docker`, `docker-compose`, `ansible`, `kubectl` (ou `minikube`) et accès Jenkins.

1) Lire les métadonnées depuis `releases.txt` et builder l'image

```bash
cd projet-fils-rouge
ODOO_URL=$(awk 'NR==1{print $2}' releases.txt)
PGADMIN_URL=$(awk 'NR==2{print $2}' releases.txt)
VERSION=$(awk 'NR==3{print $2}' releases.txt)

# build image locale
docker build -t ic-webapp:${VERSION} .

# tag pour Docker Hub (remplacez <DOCKERHUB_USER>)
DOCKERHUB_USER=kady199
docker tag ic-webapp:${VERSION} ${DOCKERHUB_USER}/ic-webapp:${VERSION}

# login & push
docker login
docker push ${DOCKERHUB_USER}/ic-webapp:${VERSION}
```

2) Test smoke local de la webapp

```bash
# run test container
docker run -d --rm --name test-ic-webapp -p 8080:8080 \
  -e ODOO_URL="${ODOO_URL}" -e PGADMIN_URL="${PGADMIN_URL}" \
  ic-webapp:${VERSION}

# attendre et tester
sleep 5
curl -fsS http://localhost:8080/ || (docker logs test-ic-webapp && exit 1)

# arrêter
docker stop test-ic-webapp
```

3) Déployer localement Odoo + Postgres (compose)

```bash
docker-compose -f docker-compose.odoo.yml up -d
docker-compose -f docker-compose.odoo.yml ps
# vérifier logs si besoin
docker-compose -f docker-compose.odoo.yml logs -f

# nettoyer
docker-compose -f docker-compose.odoo.yml down -v
```

4) Déployer localement pgAdmin (compose)

```bash
docker-compose -f docker-compose.pgadmin.yml up -d
# par défaut exposé sur le port 5050
curl -fsS http://localhost:5050/ || docker-compose -f docker-compose.pgadmin.yml logs pgadmin

# nettoyer
docker-compose -f docker-compose.pgadmin.yml down -v
```

5) Déploiement via Ansible (exemple)

```bash
cd ansible
# dry-run (vérification)
ansible-playbook -i inventory.ini deploy.yml --private-key /path/to/key -e "web_image=${DOCKERHUB_USER}/ic-webapp:${VERSION}" --check

# exécution réelle
ansible-playbook -i inventory.ini deploy.yml --private-key /path/to/key -e "web_image=${DOCKERHUB_USER}/ic-webapp:${VERSION}"
```

6) Étapes Jenkins (résumé)

- Créer dans Jenkins les credentials suivants (IDs utilisés dans `Jenkinsfile`):
  - Docker Hub username/password -> `kady199-dockerhub`
  - SSH key for Ansible -> `ansible-ssh-key`
  - GitHub token (secret text) -> `github-token`

- Importer le repo dans Jenkins et exécuter le pipeline. Le pipeline lit `releases.txt`, build/push l'image, fait un smoke test et appelle Ansible.

7) Kubernetes (exemples de commandes)

```bash
# créer namespace et label
kubectl create namespace icgroup
kubectl label namespace icgroup env=prod

# appliquer manifests (à créer dans k8s/)
kubectl apply -f k8s/ -n icgroup

# vérifier
kubectl get pods -n icgroup
kubectl get svc -n icgroup

# supprimer
kubectl delete -f k8s/ -n icgroup
kubectl delete namespace icgroup
```

8) Nettoyage général

```bash
# supprimer image locale
docker image rm ic-webapp:${VERSION} ${DOCKERHUB_USER}/ic-webapp:${VERSION} || true

# supprimer volumes orphelins
docker volume prune -f
```

---

Ceci couvre l'enchaînement standard du TP — build, test, push, déploiement via compose/Ansible, et déploiement K8s. Dites-moi si vous voulez que j'exécute maintenant le build/local run (vous avez lancé Docker) ou si je dois générer les manifests `k8s/` automatiquement.

