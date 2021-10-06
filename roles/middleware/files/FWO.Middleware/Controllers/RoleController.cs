﻿using FWO.Logging;
using FWO.Middleware.Server;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Novell.Directory.Ldap;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Threading.Tasks;

namespace FWO.Middleware.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class RoleController : ControllerBase
    {
        private readonly List<Ldap> ldaps;

        public RoleController(List<Ldap> ldaps)
        {
            this.ldaps = ldaps;
        }

        public class AddDeleteRoleParameters
        {
            public string userDn { get; set; }
        }

        // GET: api/<ValuesController>
        [HttpGet]
        [Authorize(Roles = "admin")]
        public async Task<KeyValuePair<string, List<KeyValuePair<string, string>>>[]> GetAsync()
        {
            // No parameters
            ConcurrentBag<KeyValuePair<string, List<KeyValuePair<string, string>>>> allRoles = new ConcurrentBag<KeyValuePair<string, List<KeyValuePair<string, string>>>>();
            ConcurrentBag<Task> ldapRoleRequests = new ConcurrentBag<Task>();

            foreach (Ldap currentLdap in ldaps)
            {
                if (currentLdap.HasRoleHandling())
                {
                    ldapRoleRequests.Add(Task.Run(() =>
                    {
                        // if current Ldap has roles stored: Get all roles from current Ldap
                        List<KeyValuePair<string, List<KeyValuePair<string, string>>>> currentRoles = currentLdap.GetAllRoles();
                        foreach (KeyValuePair<string, List<KeyValuePair<string, string>>> role in currentRoles)
                            allRoles.Add(role);
                    }));
                }
            }

            await Task.WhenAll(ldapRoleRequests);

            // Return status and result
            return allRoles.ToArray();
        }

        [HttpPost("{role}")]
        [Authorize(Roles = "admin")]
        public async Task<bool> AddUser(string role, [FromBody] AddDeleteRoleParameters parameters)
        {
            bool userAdded = false;
            string userDn = parameters.userDn;
            List<Task> ldapRoleRequests = new List<Task>();

            foreach (Ldap currentLdap in ldaps)
            {
                // Try to add user to role in current Ldap
                if (currentLdap.IsWritable() && currentLdap.HasRoleHandling())
                {
                    ldapRoleRequests.Add(Task.Run(() =>
                    {
                        if (currentLdap.AddUserToEntry(userDn, role))
                        {
                            userAdded = true;
                            Log.WriteAudit("AddUserToRole", $"user {userDn} successfully added to role {role} in {currentLdap.Host()}");
                        }
                    }));
                }
            }

            await Task.WhenAll(ldapRoleRequests);

            // Return status and result
            return userAdded;
        }

        [HttpDelete("{role}")]
        [Authorize(Roles = "admin")]
        public async Task<bool> RemoveUser(string role, [FromBody] AddDeleteRoleParameters parameters)
        {
            bool userRemoved = false;
            string userDn = parameters.userDn;
            List<Task> ldapRoleRequests = new List<Task>();

            foreach (Ldap currentLdap in ldaps)
            {
                // Try to remove user from role in current Ldap
                if (currentLdap.IsWritable() && currentLdap.HasRoleHandling())
                {
                    ldapRoleRequests.Add(Task.Run(() =>
                    {
                        if (currentLdap.RemoveUserFromEntry(userDn, role))
                        {
                            userRemoved = true;
                            Log.WriteAudit("RemoveUserFromRole", $"Removed user {userDn} from {role} in {currentLdap.Host()}");
                        }
                    }));
                }
            }
            await Task.WhenAll(ldapRoleRequests);

            // Return status and result
            return userRemoved;
        }
    }
}
