#!/bin/sh
# Usage: ./seed_job.sh <jenkins_url> <jenkins_user> <jenkins_api_token>
# Example: ./seed_job.sh http://localhost:9090 admin myapitoken

set -e

JENKINS_URL="$1"
JENKINS_USER="$2"
JENKINS_TOKEN="$3"
JOB_XML="jenkins/jobs/ic-webapp-pipeline.xml"
JOB_NAME="ic-webapp-pipeline"

if [ -z "$JENKINS_URL" ] || [ -z "$JENKINS_USER" ] || [ -z "$JENKINS_TOKEN" ]; then
  echo "Usage: $0 <jenkins_url> <jenkins_user> <jenkins_api_token>"
  exit 2
fi

# download jenkins-cli.jar
CLI_JAR="jenkins-cli.jar"
if [ ! -f "$CLI_JAR" ]; then
  echo "Downloading jenkins-cli.jar from ${JENKINS_URL}/jnlpJars/jenkins-cli.jar"
  curl -sSf -o "$CLI_JAR" "${JENKINS_URL}/jnlpJars/jenkins-cli.jar"
fi

# create or update job
echo "Creating/updating job ${JOB_NAME} on ${JENKINS_URL}"
java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_TOKEN" create-job "$JOB_NAME" < "$JOB_XML" || {
  echo "Job may already exist; attempting to update"
  java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_TOKEN" update-job "$JOB_NAME" < "$JOB_XML"
}

echo "Job ${JOB_NAME} created/updated."
