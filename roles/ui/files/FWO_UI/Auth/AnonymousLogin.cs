using System.Net;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Threading;
using System.Threading.Tasks;
using FWO.Middleware.Client;
using Microsoft.AspNetCore.Components.Authorization;
using FWO.ApiClient;

namespace FWO.Ui.Auth
{
    public class AnonymousLogin
    {
        private MiddlewareClient middlewareClient = new MiddlewareClient("");

        private APIConnection apiConnection;

        public AnonymousLogin()
        {
            // There is no jwt in session storage. Get one from Middleware module.
            MiddlewareServerResponse apiAuthResponse = middlewareClient.AuthenticateUser("","").Result;

            // There was an error trying to authenticate the user. Probably invalid credentials
            if (apiAuthResponse.Status == HttpStatusCode.BadRequest)
            {
                // Visualisize there was an error by making border of inputboxes red
               // exit with error?
            }
            else
            {
                apiConnection = new APIConnection(apiAuthResponse.GetResult<string>("jwt"));
            }
        }
    }
}