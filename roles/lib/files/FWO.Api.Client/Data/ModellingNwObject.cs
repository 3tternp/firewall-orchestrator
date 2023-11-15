using System.Text.Json.Serialization; 
using Newtonsoft.Json;

namespace FWO.Api.Data
{
    public class ModellingNwObject: ModellingObject
    {
        [JsonProperty("id"), JsonPropertyName("id")]
        public long Id { get; set; }

        [JsonProperty("is_deleted"), JsonPropertyName("is_deleted")]
        public bool IsDeleted { get; set; }

        public override string Display()
        {
            return (IsDeleted ? "*" : "") + Name;
        }

        public override string DisplayWithIcon()
        {
            return $"<span class=\"oi oi-tag\"></span> " + Display();
        }
    }
}
