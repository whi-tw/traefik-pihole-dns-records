Demo how to run:

```yaml
  traefik-updater:
    image: tnwhitwell/traefik-pihole-dns-records:b01719ecfd03eeb96ef45ad97fd7ef453ae910b3
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      TRAEFIK_CONTAINER_NAME: generic_traefik_1
      PIHOLE_CONTAINER_NAME: networking_pihole_1
      RULE_FILE_NAME: 03-docker.conf
