using AlwaysEncryptedSample.Services;

namespace AlwaysEncryptedSample.Migrations
{
    using System;
    using System.Data.Entity;
    using System.Data.Entity.Migrations;
    using System.Linq;

    internal sealed class AuthConfiguration : DbMigrationsConfiguration<AuthDbContext>
    {
        public AuthConfiguration()
        {
            AutomaticMigrationsEnabled = true;
            AutomaticMigrationDataLossAllowed = true;
            ContextKey = "AlwaysEncryptedSample.Models.AuthDbContext";
        }

        /// <remarks>This method will be called after migrating to the latest version.</remarks>
        protected override void Seed(AuthDbContext context)
        {
            
        }
    }

    internal sealed class AppConfiguration : DbMigrationsConfiguration<Services.ApplicationDbContext>
    {
        public AppConfiguration()
        {
            AutomaticMigrationsEnabled = true;
            AutomaticMigrationDataLossAllowed = true;
            ContextKey = "AlwaysEncryptedSample.Models.AuthDbContext";
        }
    }
}
