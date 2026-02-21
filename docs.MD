# CD Labor - Abonyi Bence Péter (D10QTW)

## Minikube telepítése
Ezt a lépést én kihagyom, mivel nekem már a gépemen a szükséges programok (minikube, docker, kubectl) fent vannak (ezen felül van még pár extra utility, k9s, helm, helm diff, stb.)

## Egyéb előkészületek
Ahhoz, hogy a github workflowk később működjenek (nomeg hogy az argonak legyen repo, amiből tud syncelni) létrehoztam egy publikus github repot, ennek a linkje:
https://github.com/benjoe1126/cd  
Mivel már voltak forrásfájlaim a repo létrehozása előtt  ezért kézzel állítottam be remotenak a következő parancsokkal
```bash
# a repo gyökerében
git init
git remote add origin git@github.com:benjoe1126/cd.git
git add .
git commit -m "initial"
git push -u origin main # ez beállítja az upstreamet és feltölti a commitunkat
```

## ArgoCD telepítése minikube-ra
Az első lépés a minikube elindítása, az asztali gépemen docker drivert használok és a `minikube start --driver=docker` paranccsal indítom  
A parancs kimenete:
![](mkstart.png)
A következő lépés az argocd telepítése.
Ehhez a parancsok
```bash
kubectl create ns argocd # létrehozzuk a namespacet
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml # szószból helm nélkül, furcsa érzés, oh well
kubectl -n argocd patch secret argocd-secret -p '{"stringData": {"admin.password": "$2a$10$mivhwttXM0U5eBrZGtAG8.VSRL1l9cZNAmaSaqotIzXRBRwID1NT.", "admin.passwordMtime": "'$(date +%FT%T)'}}"' # linux alatt works fine
# windowson nekem marad az edit, mert nem akarok ezzel vesződni
kubectl port-forward -n argocd svc/argocd-server 8080:443 # forwardoljuk az argocd-t, hogy elérjük
}}'
```
Az argocd telepítés kimenete
![](argoinstall.png)
Látható, hogy a kellő CRD-k (application, applicationset, stb.) telepítésre kerültek, ezen felül a szükséges deploymentek és servicek is létrejöttek  
Ezt követően a `kubectl port-forward ...` parancsot adtam ki, aminek az eredménye
![](portforward.png)
Az argocd login felülete port-forwardon keresztül elérve
![](argoyeah.png)
Majd az argoba belépve
![](postlogin.png)

## Tesztalkalmazás telepítése
Adjuk ki az `uv init .` parancsot, ez a függőségek kezeléséhez jól fog jönni, majd telepítsük a függőségeket
```bash
uv add flask
mkdir app
```
Ezt követően írjuk meg az app.py-t, aminek a tartalma
```python
from flask import Flask
app = Flask(__name__)
@app.route("/health")
def health():
    return "OK"
@app.route("/")
def hello_world():
    return "Hello, World!!"
if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
```
Ha ez kész, írjuk meg a dockerfile-t, helyezzük a repository gyökerébe, a tartalma legyen
```dockerfile
FROM python:3.13-alpine
WORKDIR application
COPY app/app.py .
COPY pyproject.toml .
RUN pip install uv
RUN uv sync
ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["uv", "run", "app/app.py"]
```
A következő lépés egy helm chart létrehozása  
Ehhez a következő parancsokat adtam ki a repo gyökerében
```bash
mkdir k8s
cd k8s
helm create .
```
Ez létrehoz egy helm chartot egy csomó default dologgal (templatek, _helpers.tpl, NOTES.txt).  
Töröljük a charts mappát, az összes fájlt a templates alatt, majd írjuk át a Charts.yaml tartalmát a következőre
```yaml
apiVersion: v2
name: argo-test-app # lényegében csak a név más, ha helm create argo-test-app néven hozzuk létre akkor megspóroljuk magunknak ezt az átnevezést
description: A Helm chart for Kubernetes
# A chart can be either an 'application' or a 'library' chart.
#
# Application charts are a collection of templates that can be packaged into versioned archives
# to be deployed.
#
# Library charts provide useful utilities or functions for the chart developer. They're included as
# a dependency of application charts to inject those utilities and functions into the rendering
# pipeline. Library charts do not define any templates and therefore cannot be deployed.
type: application
# This is the chart version. This version number should be incremented each time you make changes
# to the chart and its templates, including the app version.
# Versions are expected to follow Semantic Versioning (https://semver.org/)
version: 0.1.0
# This is the version number of the application being deployed. This version number should be
# incremented each time you make changes to the application. Versions are not expected to
# follow Semantic Versioning. They should reflect the version the application is using.
# It is recommended to use it with quotes.
appVersion: "1.16.0"
```
Ezt követően hozzunk létre pár helm (go) templatet a templates mappában  
deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argo-test-app1
spec:
  selector:
    matchLabels:
      app: argo-test-app1
  template:
    metadata:
      labels:
        app: argo-test-app1
    spec:
      containers:
        - name: argo-test-app1
          image: szefoka/argo-test-app1:{{ .Values.env.APP_VERSION }}
          ports:
            - name: http
              containerPort: 5000
              protocol: TCP
          readinessProbe:
            httpGet:
                path: /health
                port: 5000
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          livenessProbe:
            httpGet:
                path: /health
                port: 5000
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            successThreshold: 1
            failureThreshold: 3
```
service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: argo-test-app1
spec:
  type: LoadBalancer
  ports:
    - port: 5000
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app: argo-test-app1
```
A helm chartot ezúttal nem `helm upgrade --install`-lal rakom ki, hiszen a telpeítés és frissítés az argocd feladata lesz majd

## Github action létrehozása
A repo gyökerébe létrehozok egy .github/workflows mappát, amiben létrehozok egy cd.yaml nevű fájlt a következő tartalommal
```yaml

```
