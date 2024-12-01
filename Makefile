.PHONY: all $(MAKECMDGOALS)

build:
	docker build -t calculator-app .
	docker build -t calc-web ./web

server:
	docker run --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0

test-unit:
	docker run --name unit-tests --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/coverage.xml --cov-report=html:results/coverage --junit-xml=results/unit_result.xml -m unit || exit /b 0
	docker cp unit-tests:/opt/calc/results ./
	docker rm unit-tests || exit /b 0

test-api:
	docker network create calc-test-api || exit /b 0
	docker run -d --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run --network calc-test-api --name api-tests --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results/api_result.xml -m api || exit /b 0
	docker cp api-tests:/opt/calc/results ./
	docker stop apiserver || exit /b 0
	docker rm --force apiserver || exit /b 0
	docker stop api-tests || exit /b 0
	docker rm --force api-tests || exit /b 0
	docker network rm calc-test-api || exit /b 0

test-e2e:
	docker network create calc-test-e2e || exit /b 0
	docker stop apiserver || exit /b 0
	docker rm --force apiserver || exit /b 0
	docker stop calc-web || exit /b 0
	docker rm --force calc-web || exit /b 0
	docker stop e2e-tests || exit /b 0
	docker rm --force e2e-tests || exit /b 0
	docker run -d --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --network calc-test-e2e --name calc-web -p 80:80 calc-web
	docker create --network calc-test-e2e --name e2e-tests cypress/included:4.9.0 --browser chrome || exit /b 0
	docker cp ./test/e2e/cypress.json e2e-tests:/cypress.json
	docker cp ./test/e2e/cypress e2e-tests:/cypress
	docker start -a e2e-tests || exit /b 0
	docker cp e2e-tests:/results ./ || exit /b 0
	docker rm --force apiserver || exit /b 0
	docker rm --force calc-web || exit /b 0
	docker rm --force e2e-tests || exit /b 0
	docker network rm calc-test-e2e || exit /b 0

run-web:
	docker run --rm --volume `pwd`/web:/usr/share/nginx/html  --volume `pwd`/web/constants.local.js:/usr/share/nginx/html/constants.js --name calc-web -p 80:80 nginx

stop-web:
	docker stop calc-web

start-sonar-server:
	docker network create calc-sonar || exit /b 0
	docker run -d --rm --stop-timeout 60 --network calc-sonar --name sonarqube-server -p 9000:9000 --volume `pwd`/sonar/data:/opt/sonarqube/data --volume `pwd`/sonar/logs:/opt/sonarqube/logs sonarqube:8.3.1-community

stop-sonar-server:
	docker stop sonarqube-server
	docker network rm calc-sonar || exit /b 0

start-sonar-scanner:
	docker run --rm --network calc-sonar -v `pwd`:/usr/src sonarsource/sonar-scanner-cli

pylint:
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pylint app/ | powershell -Command "Out-File -FilePath results/pylint_result.txt -Append"

deploy-stage:
	docker stop apiserver || exit /b 0
	docker stop calc-web || exit /b 0
	docker run -d --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --rm --name calc-web -p 80:80 calc-web

stop-containers:
	docker ps --filter "name=apiserver" --filter "name=calc-web" -q | grep -q . && docker stop apiserver calc-web || echo "No containers to stop"
