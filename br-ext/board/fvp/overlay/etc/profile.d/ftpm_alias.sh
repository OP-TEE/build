alias ftpm_mod='insmod /lib/modules/extra/tpm_ftpm_tee.ko'
alias ftpm_getpcr='tpm2_pcrread'

alias ftpm='ftpm_mod && ftpm_getpcr'

alias ll='ls -al'
