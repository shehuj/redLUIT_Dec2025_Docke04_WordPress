#!/bin/bash
read -p "Enter Docker Hub username: " ${DOCKER_USERNAME}
read -s -p "Enter Docker Hub access token: " ${DOCKER_PASSWORD}
echo ""

echo "Testing credentials..."
if echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin; then
    echo "✅ SUCCESS! Credentials are valid"
    echo "Now add these to GitHub Secrets:"
    echo "  DOCKER_USERNAME: $DOCKER_USERNAME"
    echo "  DOCKER_PASSWORD: [the token you entered]"
    docker logout
else
    echo "❌ FAILED! Credentials are invalid"
    echo "Please check your username and create a new access token"
fi