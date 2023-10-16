
# Basic Alpine-based Docker Image

## Environment Variables

    MONIT_ADMIN_PASSWORD
    default: admin
    
    MONIT_MAILSERVER
    optional
    example: "smtp.gmail.com PORT 465 USERNAME <sender email address> PASSWORD <application password> using SSL"

    MONIT_OWNER
    optional
    example: <receiver email address>

    WG_DISABLED
    optional
    default: yes

    WG0_ENDPOINT
    WG0_ENDPOINT_PORT
    WG0_GATEWAY
    WG0_INTERFACE
    default: wg0

    WG0_ADDRESS
    WG0_PUBLICKEY
    WG0_PRIVATEKEY
    WG0_PSK
    WG0_ALLOWEDIPS
    WG0_KEEPALIVE
    default: 25

    WG0_PING_PERIOD
    default:10000

    PINGER_ADDRESS
    optional
