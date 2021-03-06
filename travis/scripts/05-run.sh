#!/bin/bash

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
launchCurlOrProtractor() {
    retryCount=1
    maxRetry=10
    httpUrl="http://localhost:8080"

    rep=$(curl -v "$httpUrl")
    status=$?
    while [ "$status" -ne 0 ] && [ "$retryCount" -le "$maxRetry" ]; do
        echo "[$(date)] Application not reachable yet. Sleep and retry - retryCount =" $retryCount "/" $maxRetry
        retryCount=$((retryCount+1))
        sleep 10
        rep=$(curl -v "$httpUrl")
        status=$?
    done

    if [ "$status" -ne 0 ]; then
        echo "[$(date)] Not connected after" $retryCount " retries."
        exit 1
    fi

    if [ "$PROTRACTOR" != 1 ]; then
        exit 0
    fi

    retryCount=0
    maxRetry=2
    until [ "$retryCount" -ge "$maxRetry" ]
    do
        result=0
        if [[ -f "gulpfile.js" ]]; then
            gulp itest --no-notification
        elif [[ -f "tsconfig.json" ]]; then
            npm run e2e
        fi
        result=$?
        [ $result -eq 0 ] && break
        retryCount=$((retryCount+1))
        echo "e2e tests failed... retryCount =" $retryCount "/" $maxRetry
        sleep 15
    done
    exit $result
}

#-------------------------------------------------------------------------------
# Package UAA
#-------------------------------------------------------------------------------
if [[ "$JHIPSTER" == *"uaa"* ]]; then
    cd "$UAA_APP_FOLDER"
    ./mvnw package -DskipTests=true
fi

#-------------------------------------------------------------------------------
# Package the application
#-------------------------------------------------------------------------------
cd "$APP_FOLDER"

if [ -f "mvnw" ]; then
    ./mvnw package -DskipTests=true -P"$PROFILE"
    mv target/*.war app.war
elif [ -f "gradlew" ]; then
    ./gradlew bootRepackage -P"$PROFILE" -x test
    mv build/libs/*.war app.war
else
    echo "No mvnw or gradlew"
    exit 0
fi
if [ $? -ne 0 ]; then
    echo "Error when packaging"
    exit 1
fi

#-------------------------------------------------------------------------------
# Run the application
#-------------------------------------------------------------------------------
if [ "$RUN_APP" == 1 ]; then
    if [[ "$JHIPSTER" == *"uaa"* ]]; then
        cd "$UAA_APP_FOLDER"
        java -jar target/*.war &
        sleep 80
    fi

    cd "$APP_FOLDER"
    java -jar app.war \
        --spring.profiles.active="$PROFILE" &
    sleep 40

    if [[ "$JHIPSTER" != *'micro'* ]]; then
        launchCurlOrProtractor
    fi
fi
