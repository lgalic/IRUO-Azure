[haproxy]
${public_IP} ansible_connection=ssh ansible_ssh_user=${username} ansible_ssh_pass=${password} ansible_ssh_retries=5