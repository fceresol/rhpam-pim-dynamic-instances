FROM registry.redhat.io/rhpam-7/rhpam-process-migration-rhel8:7.11.1

LABEL  "io.openshift.build.image"="registry.redhat.io/rhpam-7/rhpam-process-migration-rhel8" \
        name="Process Instance Migration With Custom Start" 




USER root
# Copying the wrapper script to  /opt/rhpam-process-migration
COPY src/bash/pimWrapper.sh /opt/rhpam-process-migration/pimWrapper.sh

# Fixing permissions
RUN chown -R 185:0 /opt/rhpam-process-migration/pimWrapper.sh
RUN chmod 774 /opt/rhpam-process-migration/pimWrapper.sh

USER 185

# Specify run cmd
CMD /opt/rhpam-process-migration/pimWrapper.sh


