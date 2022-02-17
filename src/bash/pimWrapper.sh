#!/bin/bash
# this scripts is being provided as-is, without any form of support or warranty. 
# You can modify to fit your needs.
export 
# Use the same logging as default scripts
source ${LAUNCH_DIR}/logging.sh

function setKieLDAPOverrides()
{

    cp -p /opt/rhpam-process-migration/templates/LDAPSecurity-overrides.yaml /tmp/LDAPSecurity-overrides.yaml

    for LDAP_PROPERTY in LDAP_JAVA_NAMING_PROVIDER_URL LDAP_BASE_CONTEXT_DN LDAP_BIND_CREDENTIAL LDAP_BIND_DN LDAP_BASE_FILTER LDAP_ROLE_CTX_DN LDAP_ROLE_FILTER LDAP_ROLE_ATTRIBUTE_ID ; do
        if [[ -z "${!LDAP_PROPERTY}" ]]; then
            log_warning "${!LDAP_PROPERTY} variable is not set, skipping LDAP override configuration...."
            return
        fi
        sed -i'' /tmp/LDAPSecurity-overrides.yaml -e "s#@@${LDAP_PROPERTY}@@#${!LDAP_PROPERTY}#g"
    done

    mv /tmp/LDAPSecurity-overrides.yaml /opt/rhpam-process-migration/config/

    echo -Dthorntail.security.security-domains.pim.classic-authentication.login-modules.UsersRoles.flag=Sufficient -s/opt/rhpam-process-migration/config/LDAPSecurity-overrides.yaml

}

function setRoleMappingPropertiesOverrides()
{

    if [[ -z "${ROLEMAPPING_PROPERTIES}" ]]; then
      log_warning "skipping rolemapping.properties configuration since rolemapping.properties is not set...."
      return
    fi

    echo "${ROLEMAPPING_PROPERTIES}" > /opt/rhpam-process-migration/config/rolemapping.properties
    log_info "configuring rolemapping.properties support for ldap (adding rolemapping overrides)...."
    cp -p /opt/rhpam-process-migration/templates/RoleMapping-overrides.yaml /tmp/RoleMapping-overrides.yaml

    sed -i'' /tmp/RoleMapping-overrides.yaml -e "s#@@ROLEMAP_REPLACE_ROLE@@#${ROLEMAP_REPLACE_ROLE:-"false"}#g" 

    mv /tmp/RoleMapping-overrides.yaml /opt/rhpam-process-migration/config/

    echo -s/opt/rhpam-process-migration/config/RoleMapping-overrides.yaml

}

# required vars
# KIE_SERVER_IMPORT_LIST

#
function loadKieServerConfigs()
{
    # kie server user: <KS name>_KIESERVER_USERNAME
    # kie server password: <KS name>_KIESERVER_PASSWORD
    # kie server url: http://+<KS name>_KIESERVER_SERVICE_HOST + ":" + <KS name>_KIESERVER_SERVICE_PORT + "/services/rest/server"

    KieServerName=${1}
    KieServerSvcHostEnv=${KieServerName}_KIESERVER_SERVICE_HOST
    KieServerSvcPortEnv=${KieServerName}_KIESERVER_SERVICE_PORT
    KieServerUserEnv=${KieServerName}_KIESERVER_USERNAME
    KieServerPwdEnv=${KieServerName}_KIESERVER_PASSWORD

    if [[ -z "${!KieServerSvcHostEnv}" || -z "${!KieServerSvcPortEnv}" ]]; then
        log_error "the service-related envs are not correctly configured, skipping ${KieServerName} configuration"
        echo -n ""
        return
    fi


    KieServerUrl=$(echo -n "http://${!KieServerSvcHostEnv}:${!KieServerSvcPortEnv}/services/rest/server")

    if [[ -z "${!KieServerUserEnv}" ]]; then
        log_error "the variable named ${KieServerUserEnv} is not correctly configured, skipping ${KieServerName} configuration"
        echo -n ""
        return
    fi

    KieServerUser=${!KieServerUserEnv}
    
    if [[ -z "${!KieServerPwdEnv}" ]]; then
        log_error "the variable named ${KieServerPwdEnv} is not correctly configured, skipping ${KieServerName} configuration"
        echo -n ""
        return
    fi

    KieServerPwd=${!KieServerPwdEnv}
    
    echo -n "-Dkieservers.${KIE_SERVER_INDEX}.host=${KieServerUrl} -Dkieservers.${KIE_SERVER_INDEX}.username=${KieServerUser} -Dkieservers.${KIE_SERVER_INDEX}.password=${KieServerPwd}"
}

if [[ -z "${KIE_SERVER_IMPORT_LIST}" ]]; then
    log_warning "no KIE_SERVER_IMPORT_LIST var specified, skipping..."
else
    ServerList=$(echo -n ${KIE_SERVER_IMPORT_LIST} | tr "-" "_" | tr "[a-z]" "[A-Z]")

    if [[ "${ServerList}" =~ .*ALL.* ]]; then

        log_info "ALL is selected for import, retrieving kie_server list from env"
        ServerList=""
        for server in $(env | grep "KIESERVER_SERVICE_PORT=" | awk -F "_KIESERVER_SERVICE_PORT" '{print $1}' | sort) ; do #added sort for testing only
            ServerList="${ServerList} ${server}"
        done
    fi

    KIE_SERVER_INDEX=0
    JavaParameters=""
    for server in ${ServerList} ; do
        log_info "adding server ${server} with id ${KIE_SERVER_INDEX}"
        JavaParameters="${JavaParameters} $(loadKieServerConfigs ${server})"
        
        KIE_SERVER_INDEX=$(($KIE_SERVER_INDEX + 1))
    done

    log_info "Auto-configured for: ${ServerList}"

fi

if [[ -z "${LDAP_CONFIGURE_OVERRIDE}" || "${LDAP_CONFIGURE_OVERRIDE}" == "false" ]]; then
    log_info "LDAP_CONFIGURE_OVERRIDE variable is not true, skipping LDAP override configuration...."
else
    JavaParameters="${JavaParameters} $(setKieLDAPOverrides)"
    JavaParameters="${JavaParameters} $(setRoleMappingPropertiesOverrides)"
fi

export JBOSS_KIE_EXTRA_CONFIG="${JBOSS_KIE_EXTRA_CONFIG} ${JavaParameters}"

/opt/rhpam-process-migration/openshift-launch.sh ${JBOSS_KIE_EXTRA_CONFIG}