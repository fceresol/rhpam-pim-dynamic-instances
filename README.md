# rhpam-pim-dynamic-instances
RH-PAM Process Instance migration startup customization repo

## repository content
the repo contains the following artifacts:

samples/openshift sample openshift yaml for creating 
- build config
- configmaps
- imageStream
- KieApp

src contains every file needed for the customization
- bash contains the pimWrapper.sh script
- docker the Dockerfile for generating the image
- drivers the jdbc driver jar
- templates the templates used by the wrapper to create LDAP and RoleMapping configuration fragments

### Operator configmap setup

in order to use the custom configuration file, the kieconfigs-7.11.1-pim configmap should be modified by adding:

~~~YAML
                    envFrom:
                      - configMapRef:
                          name: [[.ApplicationName]]-pim-custom-config
~~~
before the envs inside the deploymentConfig section of the process-migration.yaml file.

sample:

~~~YAML
apiVersion: v1
kind: ConfigMap
metadata:
  annotations:
    app.kiegroup.org: 7.11.1
  name: kieconfigs-7.11.1-pim
data:
  process-migration.yaml: |
    ## KIE ProcessMigration BEGIN
    processMigration:
      deploymentConfigs:

        ... missing lines ...
        
                    livenessProbe:
                      failureThreshold: 3
                      httpGet:
                        path: /health
                        port: 8080
                        scheme: HTTP
                      initialDelaySeconds: 180
                      periodSeconds: 15
                      successThreshold: 1
                      timeoutSeconds: 2
                    ######## ADD THE CUSTOMIZATION HERE ##########
                    envFrom:
                      - configMapRef:
                          name: [[.ApplicationName]]-pim-custom-config
                    ##############################################
                    env:
                      - name: JBOSS_KIE_ADMIN_USER
                        value: "[[.AdminUser]]"
                      - name: JBOSS_KIE_ADMIN_PWD
                        value: "[[.AdminPassword]]"
                      - name: JBOSS_KIE_EXTRA_CONFIG
                        value: "/opt/rhpam-process-migration/config/project-overrides.yml"
                    volumeMounts:
                      - mountPath: /opt/rhpam-process-migration/config/project-overrides.yml
                        subPath: project-overrides.yml
                        name: config
        ... missing lines ...

~~~

after that a config map named [kieapp]-pim-custom-config should be created for containing the custom configuration

### configuration

the wrapper uses the following system properties (to be specified inside [kieapp]-pim-custom-config configMap)

#### custom kie-servers

| variable name | description | required |
|-------|-------|-------|
| KIE_SERVER_IMPORT_LIST | a comma separated list of KIE_SERVER name prefix for looking up kie-server configs (if ALL is specified then autodiscovery is enabled) | true |
| <KIE_SERVER_NAME>_KIESERVER_SERVICE_HOST | host name for the given kie-server | true if the kie server is not on the same project or the kie-app name is different | 
| <KIE_SERVER_NAME>_KIESERVER_SERVICE_PORT | listen port for the given kie-server | true if the kie server is not on the same project or the kie-app name is different | 
| <KIE_SERVER_NAME>_KIESERVER_USERNAME | username for the given kie-server | true | 
| <KIE_SERVER_NAME>_KIESERVER_PASSWORD | password for the given kie-server | true | 

for example:

~~~yaml 
  KIE_SERVER_IMPORT_LIST: ALL
  RHPAM_KIESERVER1_KIESERVER_PASSWORD: kieserver_password
  RHPAM_KIESERVER1_KIESERVER_USERNAME: adminUser
  RHPAM_KIESERVER2_KIESERVER_PASSWORD: kieserver_password2
  RHPAM_KIESERVER2_KIESERVER_USERNAME: adminUser
  RHPAM_KIESERVER3_SERVICE_HOST: kie-server3.anothernamespace.svc.cluster.local
  RHPAM_KIESERVER3_KIESERVER_SERVICE_PORT: 8080 
  RHPAM_KIESERVER3_KIESERVER_PASSWORD: kieserver_password3
  RHPAM_KIESERVER3_KIESERVER_USERNAME: adminUser
  
~~~


#### custom LDAP configuration

| variable name | description | required |
|-------|-------|-------|
|LDAP_CONFIGURE_OVERRIDE | if it's set to true the LDAP configuration will be performed | true | 
|LDAP_JAVA_NAMING_PROVIDER_URL| the ldap url to connect to| true | 
LDAP_BASE_CONTEXT_DN | the base context for user lookup | true | 
| LDAP_BIND_CREDENTIAL | the credential for connecting to LDAP server | true | 
| LDAP_BIND_DN  | the username for connecting to LDAP server | true | 
| LDAP_BASE_FILTER | the filter for user querying | true | 
| LDAP_ROLE_CTX_DN | the base context for role lookup | true | 
| LDAP_ROLE_FILTER | the filter for user's role querying | true | 
| LDAP_ROLE_ATTRIBUTE_ID | the attribute containing the role name | true | 

for example:

~~~YAML
LDAP_CONFIGURE_OVERRIDE: "true"
LDAP_JAVA_NAMING_PROVIDER_URL: "ldap://192.168.1.51:10389"
LDAP_BASE_CONTEXT_DN: "ou=people,o=SevenSeas"
LDAP_BIND_CREDENTIAL: "secret"
LDAP_BIND_DN: "uid=admin,ou=system"
LDAP_BASE_FILTER: "(uid={0})"
LDAP_ROLE_CTX_DN: "ou=groups,o=sevenSeas"
LDAP_ROLE_FILTER: "uniquemember={1}"
LDAP_ROLE_ATTRIBUTE_ID: "cn"

~~~

#### custom LDAP-role / pim-role mapper
| variable name | description | required |
|-------|-------|-------|
|ROLEMAPPING_PROPERTIES| the file for mapping LDAP roles to pim roles | true | 
|ROLEMAP_REPLACE_ROLE| if true the roles retrieved from LDAP will be replaced, otherwise the roles will be appended | false (defaults to false)|

for example

~~~YAML

ROLEMAPPING_PROPERTIES: |
  LDDAPRole1=admin
  LDDAPRole2=admin
ROLEMAP_REPLACE_ROLE: "false"

~~~

NOTE: since the pim configuration allows only a single role called "admin" to access to every product feature, the rolemapping properties must contain the mapping for the group. 

#### custom jdbc Driver configuration

the only custom configuration needed for database connection is the driver jar which could be set with the JBOSS_KIE_EXTRA_CLASSPATH env. the other configurations (connection URL, credentials etc.) are available in Kie-App configuration spec by specifying "external" as database type

the driver jar inside the drivers folder will be copied under the path /opt/rhpam-process-migration/drivers/ so the configuration will contain:

~~~YAML

JBOSS_KIE_EXTRA_CLASSPATH: /opt/rhpam-process-migration/drivers/oracle-jdbc-ojdbc8.jar

~~~

Note: the same env could be used to add other custom jars to the server startup.