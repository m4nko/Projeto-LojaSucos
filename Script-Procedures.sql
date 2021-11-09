use LojaSuco
go

create procedure CadastrarCliente
@nome char(15),
@telefone char(11),
@endereco char (60),
@cpf char(11),
@planoMensal char(8) = null
as
begin transaction

	/*VERIFICA��ES*/
	if @cpf in (select cpf from cliente)
	begin
		print 'Este CPF j� est� cadastrado no sistema!'
		rollback transaction
		return -1
	end

	if @telefone in (select telefone from pessoa)
	begin
		print 'Este telefone j� est� cadastrado no sistema'
		rollback transaction
		return -1
	end

	/*OBTENDO NOVO ID*/
	declare @codigo smallint;
	select @codigo = max(id)+1 from pessoa

	if @codigo is null
		set @codigo = 0

	/*INSERINDO NA TABELA*/
	insert into pessoa
	values (@codigo, @nome, @telefone, @endereco)
	if @@ROWCOUNT > 0
		begin
			insert into cliente
			values (@codigo, @cpf, @planoMensal)
			if @@ROWCOUNT > 0
			begin
				commit transaction
				return 1
			end
			else
			begin
				rollback transaction
				return 0
			end
		end
	else
	begin
		rollback transaction
		return 0
	end
go

create procedure CadastrarInsumo
@nome char(20),
@valor smallmoney,
@idFornecedor smallint
as
begin transaction

	/*VERIFICA��ES*/
	if @valor < 0
	begin
		print 'Valor n�o pode ser menor que 0!'
		rollback transaction
		return -1
	end

	if @idFornecedor not in (select id from fornecedor)
	begin
		print 'Este fornecedor n�o existe!'
		rollback transaction
		return -1
	end

	/*OBTENDO IDs*/
	declare @idInsumo smallint
	declare @idItemFornecimento smallint

	select @idItemFornecimento = max(id)+1 from item_fornecimento

	if @idItemFornecimento is null
		set @idItemFornecimento = 0

	/*para obter o id do insumo, verificamos se ele j� existe na tabela*/
	if @nome not in (select nome from insumo)
	begin
		select @idInsumo = max(id)+1 from insumo

		if @idInsumo is null
			set @idInsumo = 0

		insert into insumo
		values (@idInsumo, @nome)
	end
	else
		select @idInsumo = (select id from insumo where nome = @nome)
	
	if @@ROWCOUNT > 0
	begin
		insert into item_fornecimento
		values (@idItemFornecimento, @idInsumo, @idFornecedor, @valor)
		if @@ROWCOUNT > 0
		begin
			commit transaction
			return 1
		end
		else
		begin
			rollback transaction
			return 0
		end
	end
	else
	begin
		rollback transaction
		return 0
	end
go


create procedure CadastrarFornecedor
@nome char(15),
@telefone char(11),
@endereco char(60),
@cnpj char(15),
@insumoFornecido char(20),
@valorInsumo smallmoney
as
begin transaction

	/*TODO: Checar se h� cnpj ou telefone repetido*/
	if @cnpj in (select cnpj from fornecedor)
	begin
		print 'Este CNPJ j� existe no sistema!'
		rollback transaction
		return -1
	end

	if @telefone in (select telefone from pessoa)
	begin
		print 'Este telefone j� existe no sistema!'
		rollback transaction
		return -1
	end

	declare @codigo smallint;
	select @codigo = max(id)+1 from pessoa

	if @codigo is null
		set @codigo = 0

	insert into pessoa
	values (@codigo, @nome, @telefone, @endereco)
	if @@ROWCOUNT > 0
	begin

		insert into fornecedor
		values (@codigo, @cnpj)
		if @@ROWCOUNT > 0
		begin
			
			declare @ret int
			exec @ret = CadastrarInsumo @insumoFornecido, @valorInsumo, @codigo

			if @@ROWCOUNT > 0 AND @ret = 1
			begin
				commit transaction
				return 1
			end
			else
			begin
				rollback transaction
				return 0
			end

		end
		else
		begin

			rollback transaction
			return 0

		end
	end
	else
	begin

		rollback transaction
		return 0

	end
go

create procedure CadastrarSuco
@codigo char(10),
@sabor char(31),
@tamanho float,
@valor smallmoney
as
begin transaction

	if @tamanho not in (0.3, 1, 1.5, 5)
	begin
		print 'O tamanho de suco n�o existe!'
		rollback transaction
		return -1
	end

	if @valor not in (6.9, 7.9, 8.9, 10.9, 11.9, 12.9, 15.9, 16.9, 17.9, 34.9, 44.9, 54.9)
	begin
			print 'O valor de suco n�o � compat�vel!'
			rollback transaction
			return -1
	end

	if @sabor in (select sabor from suco where tamanho = @tamanho)
	begin
		print 'O suco j� existe neste tamanho!'
		rollback transaction
		return -1
	end

	insert into suco
	values (@codigo, @sabor, @tamanho, @valor)
	if @@ROWCOUNT > 0
	begin
		commit transaction
		return 1
	end
	else
	begin
		rollback transaction
		return 0
	end
go

create procedure AdicionarSucoAoPedido
@idPedido smallint,
@idSuco char(10),
@quantidade smallint
as
begin transaction

	/*VERIFICA��ES*/
	if @idPedido not in (select id from pedido_cliente)
	begin
		print 'O n�mero de pedido n�o existe!'
		rollback transaction
		return -1
	end

	if @idSuco not in (select id from suco)
	begin
		print 'O suco n�o existe!'
		rollback transaction
		return -1
	end

	/*VARI�VEIS*/
	declare @valor smallmoney;
	declare @isPlanoMensal bit;

	/*caso seja plano mensal, nao adicionaremos nada ao valor total na venda*/
	select @isPlanoMensal = isPlanoMensal from pedido_cliente where id = @idPedido
	
	if @isPlanoMensal = 0 OR @isPlanoMensal = null
		select @valor = (valor)*@quantidade from suco
		where id = @idSuco
	else
		set @valor = 0

	/*INSER��O NA TABELA + ATUALIZA��O DO PE�O DA VENDA EM PEDIDO_CLIENTE*/
	insert into compor_suco
	values (@idPedido, @idSuco, @quantidade)
	if @@ROWCOUNT > 0
	begin

		update pedido_cliente
		set valorTotal += @valor - desconto
		where pedido_cliente.id = @idPedido

		declare @valorPedido smallmoney

		select @valorPedido = valorTotal from pedido_cliente
		where id = @idPedido

		if @isPlanoMensal = null OR @isPlanoMensal = 0
		begin
			commit transaction
			return 1
		end
		else if @valorPedido > 0
		begin
			commit transaction
			return 1
		end
		else
		begin
			rollback transaction
		end
	end
	else
	begin
		rollback transaction
		return 0
	end
go

create procedure NovoPedidoCliente
@idCliente smallint,
@desconto smallint = 0,
@isPlanoMensal bit,
@formaPagamento char(15) = null
as
begin transaction

	declare @idPedido smallint
	declare @valorTotal smallmoney = 0

	select @idPedido = max(id)+1 from pedido_cliente

	if @idPedido is null
		set @idPedido = 0

	insert into pedido_cliente
	values (@idPedido, @idCliente, getdate(), @isPlanoMensal, @formaPagamento, @desconto, @valorTotal)
	if @@ROWCOUNT > 0
	begin
		commit transaction
		return 1
	end
	else
	begin
		rollback transaction
		return 0
	end
go

create procedure AdicionarInsumoAoPedido
@idPedido smallint,
@idItemFornecimento smallint,
@quantidade smallint
as
begin transaction

	declare @valor smallmoney;

	select @valor = (valor)*@quantidade from item_fornecimento
	where id = @idItemFornecimento

	insert into compor_suco
	values (@idPedido, @idItemFornecimento, @quantidade)
	if @@ROWCOUNT > 0
	begin

		update pedido_fornecedor
		set valorTotal = @valor
		where pedido_fornecedor.id = @idPedido

		declare @valorPedido smallmoney

		select @valorPedido = valorTotal from pedido_fornecedor
		where id = @idPedido

		if @valorPedido > 0
		begin
			commit transaction
			return 1
		end
		else
		begin
			rollback transaction
		end

	end
	else
	begin
		rollback transaction
		return 0
	end
go

create procedure NovoPedidoFornecedor
@idItemFornecimento smallint,
@quantidade smallint,
@dataPedido date
as
begin transaction

	declare @idPedido smallint
	declare @valorTotal smallmoney = 0

	select @idPedido = max(id)+1 from pedido_fornecedor

	if @idPedido is null
		set @idPedido = 0

	select @valorTotal = valor*@quantidade from item_fornecimento
	where id = @idItemFornecimento

	insert into pedido_fornecedor
	values (@idPedido, getdate(), @valorTotal)
	if @@ROWCOUNT > 0
	begin
		commit transaction
		return 1
	end
	else
	begin
		rollback transaction
		return 0
	end
go