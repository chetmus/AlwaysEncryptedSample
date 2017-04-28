CREATE TABLE [Purchasing].[CreditCards] (
    [CreditCardId] INT          IDENTITY (1, 1) NOT NULL,
    [CardNumber]   VARCHAR (25) NOT NULL,
    [ExpMonth]     TINYINT      NOT NULL,
    [ExpYear]      SMALLINT     NOT NULL,
    [CCV]          SMALLINT     NOT NULL,
    [ModifiedDate] DATETIME     NOT NULL,
    [Network_Id]   TINYINT      NOT NULL,
    CONSTRAINT [PK_Purchasing.CreditCards] PRIMARY KEY CLUSTERED ([CreditCardId] ASC),
    CONSTRAINT [FK_Purchasing.CreditCards_Purchasing.CreditCardNetworks_Network_Id] FOREIGN KEY ([Network_Id]) REFERENCES [Purchasing].[CreditCardNetworks] ([Id]) ON DELETE CASCADE
);


GO
CREATE NONCLUSTERED INDEX [IX_Network_Id]
    ON [Purchasing].[CreditCards]([Network_Id] ASC);

