IMAGE_NAME=efi-ipxe
IMAGE_FILE=disk.img
if [ ! -f .terraform.lock.hcl ]; then
    tofu init
else
    echo "Tofu already initialized, seeing if upgrade needed"
    tofu init -upgrade
fi
if [ -z "$(openstack image list --name ${IMAGE_NAME} -c ID -f value)" ]; then
    if [ -f ${IMAGE_FILE} ]; then
        echo "Creating openstack image ${IMAGE_NAME} from ${IMAGE_FILE}"
        openstack image create \
            --disk-format raw \
            --file ${IMAGE_FILE} \
            --property hw_firmware_type='uefi' \
            --property hw_machine_type=q35 \
            --property hw_scsi_model='virtio-scsi' \
            --property hw_vif_model='e1000' \
            ${IMAGE_NAME}
        # e1000 NIC is better supported for normal kernels:
        # https://lists.openhpc.community/g/users/topic/network_hardware_error/33151796
        # https://wiki.openstack.org/wiki/VirtDriverImageProperties
    else
        echo "Need to upload ${IMAGE_NAME} image, but ${IMAGE_FILE} does not exist"
        exit 1
    fi
else
    echo "${IMAGE_NAME} image exists, delete it if you want to upload a new version"
fi
