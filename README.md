# CI/CD pipeline for Docker with DigitalOcean App Platform and GitHub Actions

How to run a node.js application in the [Digital Ocean App Platform](https://www.digitalocean.com/products/app-platform/)

## Before start

1. Create a [Digital Ocean PAT](https://docs.digitalocean.com/reference/api/create-personal-access-token/)
1. Add the PAT to your [secrets](https://docs.github.com/en/actions/reference/encrypted-secrets) with the name `DO_API_TOKEN`

## Application Confi
```yaml
name: nodejs-ci-cd-digital-ocean
region: ams
services:
- http_port: 80
  image:
    registry_type: DOCR
    repository: nodejs-ci-cd-digital-ocean
    tag: {{TAG_VERSION}}
  instance_count: 1
  instance_size_slug: basic-xxs
  name: nodejs-ci-cd-digital-ocean
  routes:
  - path: /
```

## Pipeline

```yaml
name: Node.js CI

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      DOCKER_REGISTRY: registry.digitalocean.com/<YOUR REGISTRY NAME>
      VERSION_PREFIX: 1.0.0
      APP_NAME: nodejs-ci-cd-digital-ocean
      IS_FIRST_DEPLOYMENT: 0

    steps:        
    - uses: actions/checkout@v2

    - name: Define version
      # generates a new version based on the prefix and on the gihub run number
      run: echo "APP_VERSION=$VERSION_PREFIX-$GITHUB_RUN_NUMBER" >> $GITHUB_ENV
      
    - name: GitHub Action for DigitalOcean - doctl
      uses: digitalocean/action-doctl@v2.1.0
      with:
        token: ${{ secrets.DO_API_TOKEN }}      

    - name: Log in to DigitalOcean Container Registry with short-lived credentials
      run: doctl registry login --expiry-seconds 600 

    - name: Build
      # always generate a new image suffix based on the APP_VERSION variable
      run: docker build -t "$($env:DOCKER_REGISTRY):$($env:APP_VERSION)" .
      shell: pwsh

    - name: Push image to DigitalOcean Container Registry
      run: docker push "$($env:DOCKER_REGISTRY):$($env:APP_VERSION)"
      shell: pwsh

    - name: Set the version in the YAML spec file
      run: | 
        (Get-Content ./nodejs-ci-cd-digital-ocean.yml).replace('{{TAG_VERSION}}', $env:APP_VERSION) | Set-Content ./nodejs-ci-cd-digital-ocean.yml
      shell: pwsh
      
    - name: Check if is the first deployment
      run: |        
        $allApps = @(doctl apps list --no-header --format Spec.Name)
        
        if (-not $allApps.Contains($env:APP_NAME))
        {
          echo "IS_FIRST_DEPLOYMENT=1" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        }
        
        echo "apps found:"
        $allApps
        
      shell: pwsh
      
    - name: Deploy the app for the first time
      run: |
        doctl apps create --spec nodejs-ci-cd-digital-ocean.yml
      if: env.IS_FIRST_DEPLOYMENT == '1'

    - name: Update the existing app
      run: |
        #list all apps and convert to json
        $allApps = doctl apps list -o json | ConvertFrom-Json
        
        #find the current app by name
        $currentApp = $allApps | Where { $_.spec.name -eq $env:APP_NAME }
        
        # update the app
        doctl apps update $currentApp.id --spec nodejs-ci-cd-digital-ocean.yml
        
      shell: pwsh      
      if: env.IS_FIRST_DEPLOYMENT == '0'

```
