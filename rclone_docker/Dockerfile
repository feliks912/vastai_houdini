# Use Ubuntu 20.04 LTS as the base image
FROM ubuntu:20.04

# Update system and install rclone along with CA certificates
RUN apt-get update && \
    apt-get install -y rclone ca-certificates openssl && \
    update-ca-certificates

COPY private.pem /root/private.pem
COPY decrypt_and_setup.sh /scripts/decrypt_and_setup.sh

RUN chmod +x /scripts/decrypt_and_setup.sh

# When the container starts, start the bash shell
ENTRYPOINT ["/scripts/decrypt_and_setup.sh"]
CMD ["bash"]