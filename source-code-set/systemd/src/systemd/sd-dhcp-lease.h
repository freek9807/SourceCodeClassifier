/* SPDX-License-Identifier: LGPL-2.1-or-later */
#ifndef foosddhcpleasehfoo
#define foosddhcpleasehfoo

/***
  Copyright © 2013 Intel Corporation. All rights reserved.
  systemd is free software; you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License as published by
  the Free Software Foundation; either version 2.1 of the License, or
  (at your option) any later version.

  systemd is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with systemd; If not, see <http://www.gnu.org/licenses/>.
***/

#include <errno.h>
#include <inttypes.h>
#include <net/ethernet.h>
#include <netinet/in.h>
#include <sys/types.h>

#include "_sd-common.h"

_SD_BEGIN_DECLARATIONS;

typedef struct sd_dhcp_lease sd_dhcp_lease;
typedef struct sd_dhcp_route sd_dhcp_route;

sd_dhcp_lease *sd_dhcp_lease_ref(sd_dhcp_lease *lease);
sd_dhcp_lease *sd_dhcp_lease_unref(sd_dhcp_lease *lease);

typedef enum sd_dhcp_lease_server_type_t {
        SD_DHCP_LEASE_DNS,
        SD_DHCP_LEASE_NTP,
        SD_DHCP_LEASE_SIP,
        SD_DHCP_LEASE_POP3,
        SD_DHCP_LEASE_SMTP,
        SD_DHCP_LEASE_LPR,
        _SD_DHCP_LEASE_SERVER_TYPE_MAX,
        _SD_DHCP_LEASE_SERVER_TYPE_INVALID = -EINVAL,
        _SD_ENUM_FORCE_S64(DHCP_LEASE_SERVER_TYPE),
} sd_dhcp_lease_server_type_t;

int sd_dhcp_lease_get_address(const sd_dhcp_lease *lease, struct in_addr *addr);
int sd_dhcp_lease_get_lifetime(const sd_dhcp_lease *lease, uint32_t *lifetime);
int sd_dhcp_lease_get_t1(const sd_dhcp_lease *lease, uint32_t *t1);
int sd_dhcp_lease_get_t2(const sd_dhcp_lease *lease, uint32_t *t2);
int sd_dhcp_lease_get_broadcast(const sd_dhcp_lease *lease, struct in_addr *addr);
int sd_dhcp_lease_get_netmask(const sd_dhcp_lease *lease, struct in_addr *addr);
int sd_dhcp_lease_get_router(const sd_dhcp_lease *lease, const struct in_addr **addr);
int sd_dhcp_lease_get_next_server(const sd_dhcp_lease *lease, struct in_addr *addr);
int sd_dhcp_lease_get_server_identifier(const sd_dhcp_lease *lease, struct in_addr *addr);
int sd_dhcp_lease_get_servers(const sd_dhcp_lease *lease, sd_dhcp_lease_server_type_t what, const struct in_addr **addr);
int sd_dhcp_lease_get_dns(const sd_dhcp_lease *lease, const struct in_addr **addr);
int sd_dhcp_lease_get_ntp(const sd_dhcp_lease *lease, const struct in_addr **addr);
int sd_dhcp_lease_get_sip(const sd_dhcp_lease *lease, const struct in_addr **addr);
int sd_dhcp_lease_get_pop3(const sd_dhcp_lease *lease, const struct in_addr **addr);
int sd_dhcp_lease_get_smtp(const sd_dhcp_lease *lease, const struct in_addr **addr);
int sd_dhcp_lease_get_lpr(const sd_dhcp_lease *lease, const struct in_addr **addr);
int sd_dhcp_lease_get_mtu(const sd_dhcp_lease *lease, uint16_t *mtu);
int sd_dhcp_lease_get_domainname(const sd_dhcp_lease *lease, const char **domainname);
int sd_dhcp_lease_get_search_domains(const sd_dhcp_lease *lease, char ***domains);
int sd_dhcp_lease_get_hostname(const sd_dhcp_lease *lease, const char **hostname);
int sd_dhcp_lease_get_root_path(const sd_dhcp_lease *lease, const char **root_path);
int sd_dhcp_lease_get_routes(const sd_dhcp_lease *lease, sd_dhcp_route ***routes);
int sd_dhcp_lease_get_vendor_specific(const sd_dhcp_lease *lease, const void **data, size_t *data_len);
int sd_dhcp_lease_get_client_id(const sd_dhcp_lease *lease, const void **client_id, size_t *client_id_len);
int sd_dhcp_lease_get_timezone(const sd_dhcp_lease *lease, const char **timezone);

int sd_dhcp_route_get_destination(const sd_dhcp_route *route, struct in_addr *destination);
int sd_dhcp_route_get_destination_prefix_length(const sd_dhcp_route *route, uint8_t *length);
int sd_dhcp_route_get_gateway(const sd_dhcp_route *route, struct in_addr *gateway);
int sd_dhcp_route_get_option(const sd_dhcp_route *route);

_SD_DEFINE_POINTER_CLEANUP_FUNC(sd_dhcp_lease, sd_dhcp_lease_unref);

_SD_END_DECLARATIONS;

#endif