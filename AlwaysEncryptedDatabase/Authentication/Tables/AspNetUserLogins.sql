CREATE TABLE [Authentication].[AspNetUserLogins] (
    [LoginProvider] NVARCHAR (128) NOT NULL,
    [ProviderKey]   NVARCHAR (128) NOT NULL,
    [UserId]        NVARCHAR (128) NOT NULL,
     [IDKEY] UNIQUEIDENTIFIER NOT NULL DEFAULT newid(), 
   CONSTRAINT [PK_Authentication.AspNetUserLogins] PRIMARY KEY CLUSTERED ([LoginProvider] ASC, [ProviderKey] ASC, [UserId] ASC),
    CONSTRAINT [FK_Authentication.AspNetUserLogins_Authentication.AspNetUsers_UserId] FOREIGN KEY ([UserId]) REFERENCES [Authentication].[AspNetUsers] ([Id]) ON DELETE CASCADE
);


GO
CREATE NONCLUSTERED INDEX [IX_UserId]
    ON [Authentication].[AspNetUserLogins]([UserId] ASC);

