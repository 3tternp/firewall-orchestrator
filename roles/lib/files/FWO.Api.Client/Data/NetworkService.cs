using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Serialization; 
using Newtonsoft.Json;
using System.Threading.Tasks;

namespace FWO.Api.Data
{
    public class NetworkService
    {
        [JsonProperty("svc_id"), JsonPropertyName("svc_id")]
        public long Id { get; set; }

        [JsonProperty("svc_name"), JsonPropertyName("svc_name")]
        public string Name { get; set; }

        [JsonProperty("svc_uid"), JsonPropertyName("svc_uid")]
        public string Uid { get; set; }

        [JsonProperty("svc_port"), JsonPropertyName("svc_port")]
        public int? DestinationPort { get; set; }

        [JsonProperty("svc_port_end"), JsonPropertyName("svc_port_end")]
        public int? DestinationPortEnd { get; set; }

        [JsonProperty("svc_source_port"), JsonPropertyName("svc_source_port")]
        public int? SourcePort { get; set; }

        [JsonProperty("svc_source_port_end"), JsonPropertyName("svc_source_port_end")]
        public int? SourcePortEnd { get; set; }

        [JsonProperty("svc_code"), JsonPropertyName("svc_code")]
        public string Code { get; set; }

        [JsonProperty("svc_timeout"), JsonPropertyName("svc_timeout")]
        public int? Timeout { get; set; }

        [JsonProperty("svc_typ_id"), JsonPropertyName("svc_typ_id")]
        public int? TypeId { get; set; }

        [JsonProperty("active"), JsonPropertyName("active")]
        public bool Active { get; set; }

        [JsonProperty("svc_create"), JsonPropertyName("svc_create")]
        public int Create { get; set; }

        [JsonProperty("svc_create_time"), JsonPropertyName("svc_create_time")]
        public TimeWrapper CreateTime { get; set; }

        [JsonProperty("svc_last_seen"), JsonPropertyName("svc_last_seen")]
        public int LastSeen { get; set; }

        [JsonProperty("service_type"), JsonPropertyName("service_type")]
        public NetworkServiceType Type { get; set; }

        [JsonProperty("svc_comment"), JsonPropertyName("svc_comment")]
        public string Comment { get; set; }

        [JsonProperty("svc_color_id"), JsonPropertyName("svc_color_id")]
        public int? ColorId { get; set; }

        [JsonProperty("id_proto_id"), JsonPropertyName("id_proto_id")]
        public int? ProtoId { get; set; }

        [JsonProperty("protocol_name"), JsonPropertyName("protocol_name")]
        public NetworkProtocol Protocol { get; set; }

        [JsonProperty("svc_member_names"), JsonPropertyName("svc_member_names")]
        public string MemberNames { get; set; }

        [JsonProperty("svc_member_refs"), JsonPropertyName("svc_member_refs")]
        public string MemberRefs { get; set; }

        [JsonProperty("svcgrps"), JsonPropertyName("svcgrps")]
        public Group<NetworkService>[] ServiceGroups { get; set; }

        [JsonProperty("svcgrp_flats"), JsonPropertyName("svcgrp_flats")]
        public GroupFlat<NetworkService>[] ServiceGroupFlats { get; set; }

        public override bool Equals(object obj)
        {
            switch (obj)
            {
                case NetworkService nsrv:
                    return Id == nsrv.Id;
                default:
                    return base.Equals(obj);
            }
        }

        public override int GetHashCode()
        {
            return Id.GetHashCode();
        }

        //  svc_id
        //  svc_name
        //  svc_uid
        //  svc_port
        //  svc_port_end
        //  svc_source_port
        //  svc_source_port_end
        //  svc_code
        //  svc_timeout
        //  svc_typ_id
        //  active
        //  svc_create
        //  svc_last_seen
        //  service_type: stm_svc_typ {
        //    name: svc_typ_name
        //  }
        //  svc_comment
        //  svc_color_id
        //  ip_proto_id
        //  protocol_name: stm_ip_proto {
        //    name: ip_proto_name
        //  }
        //  svc_member_names
        //  svc_member_refs
        //  svcgrps {
        //    id: svcgrp_member_id
        //    byId: serviceBySvcgrpMemberId {
        //      svc_id
        //      svc_name
        //    }
        //  }
        //  svcgrp_flats {
        //    flat_id: svcgrp_flat_id
        //    byFlatId: serviceBySvcgrpFlatMemberId {
        //      svc_id
        //      svc_name
        //    }
        //  }
    }
}
