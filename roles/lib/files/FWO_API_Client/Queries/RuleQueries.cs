﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace FWO.ApiClient.Queries
{
    public static class RuleQueries
    {

public static readonly string Rules =
@"
query ($management_id: [Int!], $device_id: [Int!], $rule_src_name: [String!], $rule_src_ip: [cidr!], $limit: Int, $offset: Int) {
  management(where: {mgm_id: {_in: $management_id}}) {
    mgm_id
    mgm_name
    devices(where: {dev_id: {_in: $device_id}}) {
      dev_id
      dev_name
      rules(limit: $limit, offset: $offset, where: {active: {_eq: true}, rule_src: {_in: $rule_src_name}, rule_disabled: {_eq: false}, rule_froms: {object: {obj_ip: {_in: $rule_src_ip}}}}) {
        rule_uid
        rule_num_numeric
        rule_name
        rule_disabled
        rule_src_neg
        rule_src
        rule_froms {
          object {
            obj_ip
            obj_name
          }
        }
        rule_dst_neg
        rule_dst
        rule_tos {
          object {
            obj_ip
            obj_name
          }
        }
        rule_svc_neg
        rule_svc
        rule_services {
          service {
            svc_name
            svc_port
            stm_svc_typ {
              svc_typ_name
            }
          }
        }
        rule_action
        rule_track
        rule_comment
      }
    }
  }
}
";

    }
}
