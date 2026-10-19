FROM nousresearch/hermes-agent:v0.22.2

COPY start.sh /opt/hermes/railway-start.sh
RUN chmod +x /opt/hermes/railway-start.sh

CMD ["/opt/hermes/railway-start.sh"]
