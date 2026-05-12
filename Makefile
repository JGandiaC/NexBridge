.PHONY: build run ssh keys clean

build:
	docker compose build

run:
	docker compose up -d

ssh:
	ssh tester@localhost -p 2222

keys:
	./generate-keys.sh

logs:
	docker compose logs -f

stop:
	docker compose down

clean:
	docker compose down -v
