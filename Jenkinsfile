pipeline {
  agent any

  environment {
    DOCKERHUB_USER = 'kady199'
    DOCKER_IMAGE_REPO = "${DOCKERHUB_USER}/ic-webapp"
  }

  parameters {
    booleanParam(name: 'BUMP_VERSION', defaultValue: false, description: 'If true, bump patch version, commit releases.txt and push tag')
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Read metadata') {
      steps {
        script {
          def lines = readFile('releases.txt').readLines()
          env.ODOO_URL = lines[0].split()[1]
          env.PGADMIN_URL = lines[1].split()[1]
          env.VERSION = lines[2].split()[1]
          echo "Read VERSION=${env.VERSION} ODOO_URL=${env.ODOO_URL} PGADMIN_URL=${env.PGADMIN_URL}"
        }
      }
    }

    stage('Build & Push Docker image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'kady199-dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PSW')]) {
          script {
            // use the known Docker Hub user and the credential for auth
            def image = "${env.DOCKER_IMAGE_REPO}:${env.VERSION}"
            sh "echo ${DH_PSW} | docker login -u ${DOCKERHUB_USER} --password-stdin"
            sh "docker build -t ${image} ."
            sh "docker push ${image}"
            env.IMAGE = image
          }
        }
      }
    }

    stage('Smoke Test') {
      steps {
        script {
          sh "docker run -d --rm --name smoke-test -p 8081:8080 ${env.IMAGE}"
          sleep 8
          sh "curl -fsS --retry 3 http://localhost:8081/ || (docker logs smoke-test && exit 1)"
          sh "docker stop smoke-test || true"
        }
      }
    }

    stage('Deploy with Ansible') {
      steps {
        withCredentials([file(credentialsId: 'ansible-ssh-key', variable: 'ANSIBLE_SSH_KEY')]) {
          script {
            sh "ansible-playbook -i ansible/inventory.ini ansible/deploy.yml --private-key ${ANSIBLE_SSH_KEY} -e \"web_image=${env.IMAGE} version=${env.VERSION}\""
          }
        }
      }
    }

    stage('Tag & Release') {
      when {
        expression { return params.BUMP_VERSION }
      }
      steps {
        script {
          // compute new patch version
          ddef cur = sh(script: '''awk 'NR==3{print $2}' releases.txt''', returnStdout: true).trim()
          echo "Current version: ${cur}"
          def parts = cur.tokenize('.')
          def major = parts[0].toInteger()
          def minor = parts[1].toInteger()
          def patch = parts[2].toInteger()
          def newver = "${major}.${minor}.${patch+1}"
          echo "New version: ${newver}"

          sh "sed -i 's/^VERSION .*/VERSION ${newver}/' releases.txt"
          sh "git config user.email \"jenkins@local\""
          sh "git config user.name \"jenkins\""
          sh "git add releases.txt"
          sh "git commit -m \"Bump version to ${newver}\" || echo 'no changes to commit'"
          sh "git tag -a v${newver} -m \"Release ${newver}\" || true"

          // Push commits and tags using GitHub token (secret text credential)
          withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
            sh "git remote set-url origin https://${GITHUB_TOKEN}@github.com/eazytraining/projet-fils-rouge.git || true"
            sh "git push https://${GITHUB_TOKEN}@github.com/eazytraining/projet-fils-rouge.git HEAD || echo 'push failed: check credentials or permissions'"
            sh "git push https://${GITHUB_TOKEN}@github.com/eazytraining/projet-fils-rouge.git --tags || echo 'push tags failed: check credentials or permissions'"
          }
        }
      }
    }
  }

  post {
    always {
      echo 'Pipeline finished.'
    }
    success {
      echo "Deployed image ${env.IMAGE}"
    }
    failure {
      echo 'Pipeline failed.'
    }
  }
}
