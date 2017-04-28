CREATE TABLE [Authentication].[AspNetUserClaims] (
    [Id]         INT            IDENTITY (1, 1) NOT NULL,
    [UserId]     NVARCHAR (128) NOT NULL,
    [ClaimType]  NVARCHAR (MAX) NULL,
    [ClaimValue] NVARCHAR (MAX) NULL,
    [IDKEY] UNIQUEIDENTIFIER NOT NULL DEFAULT newid(), 
    CONSTRAINT [PK_Authentication.AspNetUserClaims] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_Authentication.AspNetUserClaims_Authentication.AspNetUsers_UserId] FOREIGN KEY ([UserId]) REFERENCES [Authentication].[AspNetUsers] ([Id]) ON DELETE CASCADE
);


GO
CREATE NONCLUSTERED INDEX [IX_UserId]
    ON [Authentication].[AspNetUserClaims]([UserId] ASC);

