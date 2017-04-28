CREATE TABLE [Authentication].[AspNetUserRoles] (
    [UserId] NVARCHAR (128) NOT NULL,
    [RoleId] NVARCHAR (128) NOT NULL,
    CONSTRAINT [PK_Authentication.AspNetUserRoles] PRIMARY KEY CLUSTERED ([UserId] ASC, [RoleId] ASC),
    CONSTRAINT [FK_Authentication.AspNetUserRoles_Authentication.AspNetRoles_RoleId] FOREIGN KEY ([RoleId]) REFERENCES [Authentication].[AspNetRoles] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_Authentication.AspNetUserRoles_Authentication.AspNetUsers_UserId] FOREIGN KEY ([UserId]) REFERENCES [Authentication].[AspNetUsers] ([Id]) ON DELETE CASCADE
);


GO
CREATE NONCLUSTERED INDEX [IX_UserId]
    ON [Authentication].[AspNetUserRoles]([UserId] ASC);


GO
CREATE NONCLUSTERED INDEX [IX_RoleId]
    ON [Authentication].[AspNetUserRoles]([RoleId] ASC);

