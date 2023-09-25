# Add the required security libraries for Versal OP-TEE as only XilSecure is
# enabled by default

YAML_BSP_CONFIG += "plm_nvm_en plm_puf_en"

# Enable the XilNvm library to allow PLM access to eFUSEs and BBRAM
YAML_BSP_CONFIG[plm_nvm_en] = "set,true"

# Enable the XilPuf library to allow PLM access to PUF functionality
YAML_BSP_CONFIG[plm_puf_en] = "set,true"
