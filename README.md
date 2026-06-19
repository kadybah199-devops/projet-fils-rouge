# Guide d'exécution — Projet Final DevOps IC GROUP

Ce guide couvre l'enchaînement complet des trois parties du projet :
conteneurisation de la webapp, pipeline CI/CD Jenkins + Ansible, et déploiement Kubernetes.

---

## Prérequis

| Outil | Version minimale | Où l'installer |
|---|---|---|
| Docker + Docker Compose | 20.x / v2 | https://docs.docker.com/get-docker/ |
| Ansible | 2.12+ | `pip install ansible` |
| kubectl | 1.25+ | https://kubernetes.io/docs/tasks/tools/ |
| minikube | 1.30+ | https://minikube.sigs.k8s.io/docs/start/ |
| git | 2.x | natif ou https://git-scm.com |
| Compte Docker Hub | — | https://hub.docker.com |
| 3 serveurs Linux (AWS t2.micro / t2.medium ou VM) | Ubuntu 22.04 | AWS ou VirtualBox |

---

## Partie 1 — Conteneurisation de la webapp Flask

### 1.1 Cloner le dépôt

```bash
git clone https://github.com/<votre-user>/projet-fils-rouge.git
cd projet-fils-rouge
```

### 1.2 Vérifier releases.txt

```
cat releases.txt
```

Le fichier doit contenir exactement 3 lignes :

```
ODOO_URL https://www.odoo.com
PGADMIN_URL https://www.pgadmin.org
VERSION 1.0
```

### 1.3 Builder l'image ic-webapp:1.0

```bash
docker build -t ic-webapp:1.0 .
```
<img width="1019" height="279" alt="image" src="https://github.com/user-attachments/assets/d1b7f89e-f82f-48d4-a575-325948ea787a" />

Le Dockerfile lit automatiquement `releases.txt` via `awk` pendant le build et injecte les URLs dans `/etc/profile.d/icenv.sh`.

Vérifier que l'image est bien créée :

```bash
docker images | grep ic-webapp
```
<img width="1002" height="275" alt="image" src="https://github.com/user-attachments/assets/73f9dcac-ee82-41e2-8d2b-ad57cb73e6db" />

### 1.4 Lancer le container de test

```bash
docker run -d --name test-ic-webapp -p 8080:8080 \
  -e ODOO_URL=https://www.odoo.com \
  -e PGADMIN_URL=https://www.pgadmin.org \
  ic-webapp:1.0
```
![Uploading image.png…]()

Vérifier que le site vitrine est accessible :

```bash
curl -fsS http://localhost:8080/
# ou ouvrir http://localhost:8080 dans un navigateur
```

Les liens vers Odoo et pgAdmin doivent apparaître sur la page.

### 1.5 Supprimer le container de test

```bash
docker stop test-ic-webapp
docker rm test-ic-webapp
```

### 1.6 Pousser l'image sur Docker Hub

```bash
docker login
docker tag ic-webapp:1.0 kady199/ic-webapp:1.0
docker push kady199/ic-webapp:1.0
```

---

## Partie 2 — Pipeline CI/CD avec Jenkins et Ansible

### 2.1 Mettre en place l'infrastructure (3 serveurs)

| Serveur | Rôle | Type recommandé |
|---|---|---|
| Serveur 1 | Jenkins (CI/CD) | t2.medium, port 8080 ouvert |
| Serveur 2 | Webapp vitrine + pgAdmin | t2.micro |
| Serveur 3 | Odoo | t2.micro |

Installer Docker sur les serveurs 2 et 3 :

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo apt-get install -y docker-compose
```

### 2.2 Déployer Jenkins (Serveur 1)

Sur le Serveur 1 :

```bash
cd jenkins-tools
docker-compose up -d
```

Jenkins sera accessible sur `http://<IP-serveur1>:8080`.

Récupérer le mot de passe initial :

```bash
docker exec -it <container_jenkins> cat /var/lib/jenkins/secrets/initialAdminPassword
```

Installer les plugins recommandés lors du premier démarrage.

### 2.3 Configurer les credentials Jenkins

Dans **Manage Jenkins → Credentials → Global**, créer :

| ID | Type | Valeur |
|---|---|---|
| `kady199-dockerhub` | Username/Password | Votre login Docker Hub |
| `ansible-ssh-key` | SSH Private Key | Clé SSH privée vers serveurs 2 et 3 |
| `github-token` | Secret text | Token GitHub (scope: repo) |

### 2.4 Créer le job Jenkins

Option A — via le script automatique :

```bash
./jenkins/seed_job.sh http://<IP-serveur1>:8080 admin <api_token>
```

Option B — manuellement dans l'interface Jenkins :
- Nouveau projet → Pipeline
- Définition : Pipeline script from SCM
- SCM : Git, URL de votre dépôt
- Script Path : `Jenkinsfile`

### 2.5 Adapter l'inventaire Ansible

Éditer `ansible/inventory.ini` avec les adresses IP réelles :

```ini
[app_servers]
app1 ansible_host=<IP-serveur2> ansible_user=ubuntu

[odoo_servers]
odoo1 ansible_host=<IP-serveur3> ansible_user=ubuntu

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### 2.6 Lancer le pipeline manuellement (première fois)

Dans Jenkins, ouvrir le job `ic-webapp-pipeline` → **Build Now**.

Le pipeline exécute dans l'ordre :
1. **Checkout** — récupère le code depuis Git
2. **Read metadata** — lit VERSION, ODOO_URL, PGADMIN_URL depuis `releases.txt`
3. **Build & Push** — construit l'image `kady199/ic-webapp:<VERSION>` et la pousse sur Docker Hub
4. **Smoke Test** — lance un container temporaire sur le port 8081 et teste avec `curl`
5. **Deploy with Ansible** — exécute `ansible/deploy.yml` qui déploie Odoo et pgAdmin via les rôles
6. **Tag & Release** — (optionnel, activé via le paramètre `BUMP_VERSION`)

### 2.7 Tester le déploiement Ansible seul (optionnel)

```bash
cd ansible
ansible-playbook -i inventory.ini deploy.yml \
  --private-key /chemin/vers/cle_ssh \
  -e "web_image=kady199/ic-webapp:1.0 version=1.0"
```

### 2.8 Déclencher automatiquement avec releases.txt v1.1

Modifier `releases.txt` :

```
ODOO_URL https://www.odoo.com
PGADMIN_URL https://www.pgadmin.org
VERSION 1.1
```

Committer et pousser :

```bash
git add releases.txt
git commit -m "Bump version to 1.1"
git push origin main
```

Si un webhook GitHub est configuré sur Jenkins, le pipeline se déclenche automatiquement.
Sinon, lancer manuellement depuis l'interface Jenkins.

Vérifier que l'image `kady199/ic-webapp:1.1` apparaît sur Docker Hub et que les applications sont bien déployées.

### 2.9 Vérifier les applications déployées

Sur Serveur 2 (webapp + pgAdmin) :
```bash
docker ps
curl http://localhost:8080/       # Site vitrine
curl http://localhost:5050/       # pgAdmin
```

Sur Serveur 3 (Odoo) :
```bash
docker ps
curl http://localhost:8069/       # Odoo
```

---

## Partie 3 — Déploiement Kubernetes sur Minikube

### 3.1 Démarrer Minikube

```bash
minikube start --driver=docker
minikube status
```

### 3.2 Créer le namespace icgroup

```bash
kubectl apply -f k8s/namespace.yaml
kubectl get namespace icgroup
```

### 3.3 Créer les volumes persistants (PV + PVC)

Créer les répertoires de stockage sur l'hôte Minikube :

```bash
minikube ssh "sudo mkdir -p /mnt/data/odoo/filestore /mnt/data/odoo/postgres /mnt/data/pgadmin"
```

Appliquer les manifests PV/PVC :

```bash
kubectl apply -f k8s/odoo-pv-pvc.yaml
kubectl apply -f k8s/postgres-pv-pvc.yaml
kubectl apply -f k8s/pgadmin-pv-pvc.yaml

kubectl get pv,pvc -n icgroup
```

Les PVC doivent passer en statut `Bound`.

### 3.4 Déployer PostgreSQL

```bash
kubectl apply -f k8s/postgres-deployment.yaml
kubectl get pods -n icgroup -l app=postgres
kubectl get svc -n icgroup postgres-service
```

Attendre que le pod soit `Running` avant de continuer.

### 3.5 Déployer Odoo

```bash
kubectl apply -f k8s/odoo-deployment.yaml
kubectl get pods -n icgroup -l app=odoo
kubectl get svc -n icgroup odoo-service
```

Récupérer l'URL d'accès :

```bash
minikube service odoo-service -n icgroup --url
```

Ouvrir l'URL dans un navigateur pour vérifier Odoo.

### 3.6 Déployer pgAdmin

Appliquer le ConfigMap (servers.json) puis le déploiement :

```bash
kubectl apply -f k8s/pgadmin-configmap.yaml
kubectl apply -f k8s/pgadmin-deployment.yaml

kubectl get pods -n icgroup -l app=pgadmin
kubectl get svc -n icgroup pgadmin-service
```

Récupérer l'URL d'accès :

```bash
minikube service pgadmin-service -n icgroup --url
```

Se connecter avec `admin@local` / `admin`. La connexion à la base Odoo doit apparaître automatiquement dans le panneau de gauche (grâce au `servers.json` monté via ConfigMap).

### 3.7 Vérifier l'ensemble des ressources

```bash
kubectl get all -n icgroup
kubectl get pv,pvc -n icgroup
kubectl get configmap -n icgroup
```

Vérifier que chaque ressource porte le label `env=prod` :

```bash
kubectl get all -n icgroup --show-labels
```

### 3.8 Tester la persistance des données

Supprimer les pods et vérifier que les données survivent au redémarrage :

```bash
kubectl delete pod -n icgroup -l app=postgres
# Le pod se recrée automatiquement (contrôlé par le Deployment)
kubectl get pods -n icgroup -w
# Vérifier que les données Odoo sont toujours présentes après reconnexion
```

### 3.9 Nettoyage (fin de démonstration)

```bash
kubectl delete -f k8s/ -n icgroup
kubectl delete namespace icgroup
minikube stop
```

---

## Récapitulatif des ports d'accès

| Application | Environnement Docker Compose | Environnement Kubernetes |
|---|---|---|
| Site vitrine Flask | `http://<serveur2>:8080` | — |
| Odoo | `http://<serveur3>:8069` | `minikube service odoo-service -n icgroup --url` |
| pgAdmin | `http://<serveur2>:5050` | `minikube service pgadmin-service -n icgroup --url` |
| Jenkins | `http://<serveur1>:8080` | — |

---

## Credentials Jenkins requis (récapitulatif)

| ID credential | Type | Usage |
|---|---|---|
| `kady199-dockerhub` | Username/Password | Push de l'image Docker Hub |
| `ansible-ssh-key` | SSH Private Key | Connexion SSH aux serveurs distants |
| `github-token` | Secret text | Push Git (Tag & Release) |

---

## Identification des ressources Kubernetes (Architecture A…H)

En se basant sur l'architecture Minikube à un seul nœud :

| Ressource | Type K8s | Rôle |
|---|---|---|
| A | Namespace `icgroup` | Isolation logique de toutes les ressources du projet |
| B | Deployment `postgres-deployment` | Gère le pod PostgreSQL, assure la relance automatique |
| C | Service `postgres-service` (ClusterIP) | Expose PostgreSQL en interne au cluster (port 5432) |
| D | Deployment `odoo-deployment` | Gère le pod Odoo 13.0 |
| E | Service `odoo-service` (NodePort 30069) | Expose Odoo vers l'extérieur |
| F | Deployment `pgadmin-deployment` | Gère le pod pgAdmin |
| G | Service `pgadmin-service` (NodePort 30500) | Expose pgAdmin vers l'extérieur |
| H | PersistentVolume + PersistentVolumeClaim | Assure la persistance des données (Odoo, Postgres, pgAdmin) |
