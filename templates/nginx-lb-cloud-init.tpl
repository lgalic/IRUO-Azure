#cloud-config
package_upgrade: true
packages:
    - haproxy

runcmd:
  - |
    cat >> /etc/haproxy/haproxy.cfg << EOF

    frontend https-in
      mode http
      bind *:80
      bind *:443 ssl crt /etc/haproxy/haproxy.pem
      default_backend backend_servers
      option http-server-close
      http-request set-header X-Forwarded-Proto https if { ssl_fc }
      http-request redirect scheme https code 301 if !{ ssl_fc }


    backend backend_servers
      balance roundrobin
      server ${wp1} ${wp1_address}:80 check
      server ${wp2} ${wp2_address}:80 check
    EOF

    systemctl enable haproxy --now
    systemctl restart haproxy
