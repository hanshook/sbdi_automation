# bind9 

This role has been copied [from](https://github.com/OSSHelp/ansible-bind9)

[![Build Status](https://drone.osshelp.ru/api/badges/ansible/bind9/status.svg)](https://drone.osshelp.ru/ansible/bind9)

Ansible role, which installs Bind 9.x and manages resolv.conf contents.

## Usage (example)

```yaml
    - role: bind9
```

Check [this playbook](molecule/custom/playbook.yml) for example of role call with custom parameters.

## Available parameters

### Main

| Param | Description |
| -------- | -------- |
| `bind9_ipv4_only` | Whether to enable "IPv4 only" mode. |
| `bind9_custom_nameservers` | Array of two nameservers that will be used in addition to default one in resolv.conf. |
| `bind9_custom_options` | Array for adding custom options to named.conf.options file. Must be presented as a key-value list. |
| `bind9_resolv_conf_options` | Array for adding custom options to resolv.conf file. Must be presented as a key-value list. |
| `bind9_listen_ipv4.addresses` | Array of IPv4 addresses to listen on. |
| `bind9_listen_ipv6.addresses` | Array of IPv6 addresses to listen on. |

### Misc

| Param | Description |
| -------- | -------- |
| `bind9_default_nameserver` | Default nameserver address, will be used for the first nameserver directive in resolv.conf. |
| `bind9_default_trusted_addresses` | Array with default trusted addresses. |
| `bind9_custom_trusted_addresses` | Addresses from this array will be added to trusted list. |
| `bind9_include_configs` | Absolute paths to configurations files, that will be included in local config. |
| `bind9_auth_nxdomain` | Value of auth-nxdomain paramater ('no', by default). If set to yes, the server will be allowed to answer authoritatively when returning NXDOMAIN answers. |
| `bind9_packages` | List of packages to install. |
| `bind9_dnssec_validation.enabled` | Whether to add dnssec-validation to configuration file. |
| `bind9_dnssec_validation.mode` | Value for dnssec-validation param ('auto' by default). |
| `bind9_lxd_forward.enable` | Value for enable lxd forwarders ('false' by default). |
| `bind9_lxd_forward.forwarders` | List for lxd forwarders (Empty by default). |
| `bind9_enable_statistics` | Value for enable keeping statistics ('true' by default). |
| `bind9_slave_zones` | Optional list of slave zones to create. Check [this playbook](molecule/custom/playbook.yml) for usage example. |

## Supported Ubuntu codenames

- bionic
- focal

## FAQ

None, so far.

## Useful links

- [Administrator Reference Manual](https://bind9.readthedocs.io/en/latest/#)
- [Our article](https://oss.help/kb23)

## TODO

- Find a solution for creating named.stats in the case when installing bind in container

## License

GPL3

## Author

OSSHelp Team, see <https://oss.help>
