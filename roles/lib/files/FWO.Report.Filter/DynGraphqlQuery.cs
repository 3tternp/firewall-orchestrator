using FWO.Report.Filter.Ast;
using System.Collections.Generic;
using FWO.ApiClient.Queries;
using System.Text.RegularExpressions;

namespace FWO.Report.Filter
{
    public class DynGraphqlQuery
    {
        public int parameterCounter = 0;
        public Dictionary<string, object> QueryVariables { get; set; } = new Dictionary<string, object>();
        public string FullQuery { get; set; } = "";
        public string ruleWhereStatement { get; set; } = "";
        public string nwObjWhereStatement { get; set; } = "";
        public string svcObjWhereStatement { get; set; } = "";
        public string userObjWhereStatement { get; set; } = "";
        public List<string> QueryParameters { get; set; } = new List<string>()
        {
            " $limit: Int ",
            " $offset: Int ",
            " $mgmId: [Int!]",
            " $relevantImportId: bigint"
        };
        public string ReportTime { get; set; } = "";
        public string ReportType { get; set; } = "";

        // $mgmId and $relevantImporId are only needed for time based filtering
        private DynGraphqlQuery() { }

        public static DynGraphqlQuery Generate(AstNode ast)
        {
            // this.ast = ast;
            string ruleOverviewFragment = RuleQueries.ruleOverviewFragments;

            DynGraphqlQuery query = new DynGraphqlQuery();

            // now we convert the ast into a graphql query:
            ast.Extract(ref query);

            // if any filter is set, optionally leave out all header texts

            string paramString = string.Join(" ", query.QueryParameters.ToArray());
            switch (query.ReportType)
            {
                // todo: move $mdmId filter from management into query.xxxWhereStatement
                // management(where: {{mgm_id: {{_in: $mgmId }} }} order_by: {{ mgm_name: asc }}) 
                        // management(order_by: {{ mgm_name: asc }}) 
                case "statistics":
                    query.FullQuery = $@"
                    query statisticsReport ({paramString}) 
                    {{ 
                        management(
                            where: {{ 
                                hide_in_gui: {{_eq: false }}  
                                mgm_id: {{_in: $mgmId }} 
                            }}
                            order_by: {{ mgm_name: asc }}
                        ) 
                        {{
                            name: mgm_name
                            id: mgm_id
                            objects_aggregate(where: {{ {query.nwObjWhereStatement} }}) {{ aggregate {{ count }} }}
                            services_aggregate(where: {{ {query.svcObjWhereStatement} }}) {{ aggregate {{ count }} }}
                            usrs_aggregate(where: {{ {query.userObjWhereStatement} }}) {{ aggregate {{ count }} }}
                            rules_aggregate(where: {{ {query.ruleWhereStatement} }}) {{ aggregate {{ count }} }}
                            devices( where: {{ hide_in_gui: {{_eq: false }} }} order_by: {{ dev_name: asc }} )
                            {{
                                name: dev_name
                                id: dev_id
                                rules_aggregate(where: {{ {query.ruleWhereStatement} }}) {{ aggregate {{ count }} }}
                            }}
                        }}
                    }}";
                    break;                

                case "rules":
                    query.FullQuery = $@"
                    {ruleOverviewFragment}

                    query rulesReport ({paramString}) 
                    {{ 
                        management( where: {{ mgm_id: {{_in: $mgmId }}, hide_in_gui: {{_eq: false }} }} order_by: {{ mgm_name: asc }} ) 
                            {{
                                id: mgm_id
                                name: mgm_name
                                devices ( where: {{ hide_in_gui: {{_eq: false }} }} order_by: {{ dev_name: asc }} ) 
                                    {{
                                        id: dev_id
                                        name: dev_name
                                        rules(
                                            limit: $limit 
                                            offset: $offset
                                            where: {{ {query.ruleWhereStatement} }} 
                                            order_by: {{ rule_num_numeric: asc }} )
                                            {{
                                                ...ruleOverview
                                            }} 
                                    }}
                            }} 
                    }}";
                    break;
                case "changes":
                    query.FullQuery = $@"
                    {ruleOverviewFragment}

                    query changeReport({paramString}) {{
                        management(where: {{ hide_in_gui: {{_eq: false }} }} order_by: {{mgm_name: asc}}) 
                        {{
                            id: mgm_id
                            name: mgm_name
                            devices (where: {{ hide_in_gui: {{_eq: false }} }} order_by: {{dev_name: asc}}) 
                            {{
                                id: dev_id
                                name: dev_name
                                changelog_rules(
                                    offset: $offset 
                                    limit: $limit 
                                    where: {{ {query.ruleWhereStatement} }}
                                    order_by: {{ control_id: asc }}
                                ) 
                                    {{
                                        import: import_control {{ time: stop_time }}
                                        change_action
                                        old: ruleByOldRuleId {{
                                        ...ruleOverview
                                        }}
                                        new: rule {{
                                        ...ruleOverview
                                        }}
                                    }}
                                }}
                            }}
                        }}
                    ";
                    break;
            }

            // remove line breaks and duplicate whitespaces
            Regex pattern = new Regex("\n");
            pattern.Replace(query.FullQuery, "");
            pattern = new Regex("[ ]{2}");
            pattern.Replace(query.FullQuery, "");
            return query;
        }
    }
}
