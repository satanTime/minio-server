#!/bin/bash

if [[ -f .url ]]; then
    URL=$(cat .url)
fi
if [[ $URL == "" ]]; then
    URL=https://registry.hub.docker.com/v2/repositories/minio/minio/tags
fi

while [[ $URL != "" ]]; do
    echo $URL > .url

    exitCode=1
    while [[ $exitCode != 0 ]]; do
        content=$(curl -s $URL)
        exitCode=$?
        echo "$exitCode - $URL"
    done

    URL=$(
        echo $content | \
        grep -oE '"next":"https://registry.hub.docker.com/v2/[^"]+"' | \
        sed -e 's/^"next":"//' | \
        sed -e 's/"$//'
    )
    tags=$(
        echo $content | \
        grep -oE '"name":"[^"]+"' | \
        sed -e 's/^"name":"//' | \
        sed -e 's/"$//' | \
        grep -vE "^edge.*" | \
        grep -vE '^\d{4,}-.*'
    )
    for tag in $tags; do
        exitCode=1
        while [[ $exitCode != 0 ]]; do
            content=$(curl -s https://registry.hub.docker.com/v2/repositories/minio/minio/tags/$tag)
            exitCode=$?
            echo "$exitCode - https://registry.hub.docker.com/v2/repositories/minio/minio/tags/$tag"
        done

        platforms=$(
            echo $content | \
            grep -oE '"architecture":"[^"]+"' | \
            sed -e 's/^"architecture":"//' | \
            sed -e 's/"$//' | \
            sed -e 's/^/linux\//' | \
            tr '\n' ',' | \
            sed -e 's/,$//'
        )
        digestCurrent=$(
            echo $content | \
            grep -oE '"digest":"[^"]+"' | \
            sed -e 's/^"digest":"//' | \
            sed -e 's/"$//'
        )
        digestOld=$(cat hashes/$tag 2> /dev/null)
        if [[ "$(echo "$digestCurrent" | sort)" != "$(echo "$digestOld" | sort)" ]] && [[ $digestCurrent != "" ]] || [[ -f hashes/$tag.error ]] || [[ -f "hashes/${tag}@error" ]]; then
            echo "FROM minio/minio:${tag}" > Dockerfile && \
            cat Dockerfile.template >> Dockerfile && \
            docker buildx build \
                --platform $platforms \
                -t satantime/minio-server:$tag --push . && \
            rm Dockerfile && \
            printf '%s\n' $digestCurrent > hashes/$tag && \
            git add --all && \
            git commit -m "Update of ${tag} on $(date +%Y-%m-%d)" && \
            sleep 0;
        fi
        sleep 0;
    done;
    sleep 0;
done
rm .url
