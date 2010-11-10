#
#   o_dbm.rb - オブジェクト指向データベース風Object Base dbm
#   	$Release Version: 0.2$
#   	$Revision: 1.3 $
#   	$Date: 1998/03/29 17:09:12 $
#   	by Keiju ISHITSUKA(Nippon Rational Inc.)
#
# --
#
#   
#

require "e2mmap"
require "dbm"
require "marshal"

class ObjectDBM
  @RCS_ID='-$Id: o_dbm.rb,v 1.3 1998/03/29 17:09:12 keiju Exp $-'

  extend Exception2MessageMapper

  # トップトランザクションでしか実行できないオペレーションを実行しよう
  # とした.  
  def_exception(:ErrOnlyUsableTopTransaction, 
		"This operation(%s) only executable top transaction.")

  # トランザクション内でないと実行できないオペレーションを実行しようと
  # しました.
  def_exception(:ErrOnlyUsableInTransaction, 
		"This operation(%s) only executable in transaction.")

  # 静的トランザクションと動的トランザクションを混在して利用することは
  # できません. 
  def_exception(:ErrMixedTransaction, 
		"Static transaction and Dynamic transaction can't use mixed")

  include Enumerable

  ODBM = ObjectDBM

  STATIC_TRANSACTION_MODE = :ObjectDBM__STATIC_TRANSACTION_MODE
  DYNAMIC_TRANSACTION_MODE = :ObjectDBM__DYNAMIC_TRANSACTION_MODE

  NO_CACHING = :ObjectDBM__NO_CACHING
  READ_CACHING = :ObjectDBM__READ_CACHING
  UPDATE_CACHING = :ObjectDBM__UPDATE_CACHING

  CLEAR_READ_CACHE = :ObjectDBM__CLEAR_READ_CACHE
  HOLD_READ_CACHE = :ObjectDBM__HOLD_READ_CACHE

  READ = :ObjectDBM__READ
  UPDATE = :ObjectDBM__UPDATE
  ABORT = :ObjectDBM__ABORT

  TRANSACTIONAL_OPERATIONS = [
    "[]", "update", "[]=", "delete", "indexes",
    "root_names", "keys", "roots", "values",
    "size"
  ]

  #----------------------------------------------------------------------
  #
  #  initialize and terminating  - 
  #	initialize
  #
  #----------------------------------------------------------------------
  def initialize(dbm_name)
    @dbm_name = File.expand_path(dbm_name)
    @dbm = nil

    @transaction_mode = nil
    @default_caching_mode = nil
    @read_cache = nil
    @write_cache = nil
    @delete_cache = nil

    @current_transaction = nil

    unusable_methods
  end

  def unusable_methods
  end

  def u1
    for op in TRANSACTIONAL_OPERATIONS
      instance_eval %[
	def #{op} 
	  error_not_transaction_start("#{op}")
	end
      ]
    end
  end
  private :unusable_methods

  def usable_methods
  end

  def u2
    for op in TRANSACTIONAL_OPERATIONS
      instance_eval "undef #{op}"
    end
  end
  private :usable_methods

  def error_not_transaction_start(op)
    ODBM.fail ErrOnlyUsableInTransaction, op
  end
  private :error_not_transaction_start
    
  #----------------------------------------------------------------------
  #
  #  accessing  - 
  #	[](key, mode)
  #	update(key, obj)
  #	[]=(key, obj)
  #	delete(key)
  #	indexes
  #	root_names
  #	keys
  #	roots
  #	values
  #	size
  #
  #----------------------------------------------------------------------
  def [](key, mode = nil)
    mode = @default_caching_mode unless mode

    return update(key) if mode == UPDATE
    obj = @read_cache[key]
    return obj unless obj.nil?
      
    return nil unless s = @dbm[key]
    obj = Marshal.load(s)
    @read_cache[key] = obj if mode != NO_CACHING
    obj
  end

  def update(key, obj = nil)
    return self[key] = obj unless obj.nil?
    return @write_cache[key] = obj unless (obj = @read_cache[key]).nil?
    ODBM.fail ErrOnlyUsableInTransaction, "[]"
    return nil unless s = @dbm[key]
    @write_cache[key] = @read_cache[key] = Marshal.load(s)
  end

  def []=(key, obj)
    return delete(key) if obj.nil?
    @write_cache[key] = @read_cache[key] = obj
    @delete_cache.delete(key)
  end

  def delete(key)
    @write_cache.delete(key)
    @read_cache.delete(key)
    @delete_cache[key] = TRUE
  end

  def indexes(*keys)
    keys.collect{|key| self[key]}
  end

  def roots
    keys = []
    each_keys do
      |key|
      keys.push = keys
    end
    keys
  end
  alias keys roots

  def size
    no = 0
    each_keys do
      |key|
      no += 1
    end
    no
  end

  def roots(mode = nil)
    values = []
    each_root(mode) do
      |root|
      values.push root
    end
    values
  end
  alias values roots

  #----------------------------------------------------------------------
  #
  #  testing  - 
  #	has_root_name?
  #	root_name?
  #	include?
  #	has_root?
  #	root?
  #
  #----------------------------------------------------------------------
  def has_root_name?(root_name)
    @current_transaction.has_root_name?(root_name)
  end
  alias root_name? has_root_name?
  alias include? has_root_name?

  def has_root?(root)
    @read_cache.each_value do
      |r|
      return TRUE if root.eq?(r)
    end
    FALSE
  end
  alias root? has_root?

  #----------------------------------------------------------------------
  #
  #  enumerating  - 
  #	each
  #	each_pair
  #	each_root_name
  #	each_key
  #	each_root
  #	each_value
  #
  #----------------------------------------------------------------------
  def each(mode = nil)
    mode = @default_caching_mode unless mode

    for key, value in @read_cache
      @write_cache[key] = value if mode == UPDATE
      yield key, value
    end

    @dbm.each_key do
      |key|
      if @read_cache[key].nil?
	obj = Marshal.load(@dbm[key]) 
	@read_cache[key] = obj if mode == READ_CACHING
	@write_cache[key] = obj if mode == UPDATE
	yield key, obj
      end
    end
  end
  alias each_pair each

  def each_root_name
    @read_cache.each_key do
      |key|
      yield key
    end
      
    @dbm.each_key do
      |key|
      yield key if @read_cache[key].nil?
    end
  end
  alias each_key each_root_name

  def each_root(mode = nil)
    mode = @default_caching_mode unless mode

    each(mode) do
      |key, root|
      yield root
    end
  end
  alias each_value each_root

  #----------------------------------------------------------------------
  #
  #   transaction accessing - 
  #	transaction
  #     current_transaction
  #
  #----------------------------------------------------------------------
  def transaction(mode = READ_CACHING)
    @default_caching_mode = mode
    open(mode)

    outer = @current_transaction
    if outer
      # freeze old cache
      outer.read_cache = @read_cache.dup
      outer.write_cache = @write_cache.dup
      outer.delete_cache = @delete_cache.dup
    end

    if iterator?
      if @transaction_mode == DYNAMIC_TRANSACTION_MODE
	ODBM.fail ErrMixedTransaction 
      end
      @transaction_mode = STATIC_TRANSACTION_MODE
      @current_transaction = StaticTransaction.new(self, mode, outer)
      @current_transaction.transaction do
	yield @current_transaction
      end
    else
      if @transaction_mode == STATIC_TRANSACTION_MODE
	ODBM.fail ErrMixedTransaction 
      end
      
      @transaction_mode = DYNAMIC_TRANSACTION_MODE

      @current_transaction = DynamicTransaction.new(self, mode, outer)
      @current_transaction.start
      return @current_transaction
    end

  end
  attr :current_transaction

  #----------------------------------------------------------------------
  #
  #  openning and closing  - system fuctions
  #
  #----------------------------------------------------------------------
  def commit(txn)
    @current_transaction = txn.outer
    if @current_transaction
      @mode = @current_transaction.mode
      @current_transaction.read_cache = @read_cache
      @current_transaction.write_cache = @write_cache
      @current_transaction.delete_cache = @delete_cache
    else
      close
    end
  end

  def flush(txn)
    if txn.outer
      txn.outer.read_cache = txn.read_cache.dup
      txn.outer.write_cache = txn.write_cache.dup
      txn.outer.delete_cache = txn.delete_cache.dup
    else
      close(HOLD_READ_CACHE)
      @dbm = DBM.open(@dbm_name)
    end
  end

  def abort(txn)
    @current_transaction = txn.outer
    if @current_transaction
      @mode = @current_transaction.mode
      @read_cache = @current_transaction.read_cache
      @write_cache = @current_transaction.write_cache
      @delete_cache = @current_transaction.delete_cache
    else
      close_with_no_flush
    end
  end
  public :abort

  def open(mode = READ_CACHING)
    @dbm = DBM.open(@dbm_name) unless @dbm
    @read_cache = {} unless @read_cache
    @write_cache = {} unless @write_cache
    @delete_cache = {} unless @delete_cache

    usable_methods
    self
  end
  private :open

  def flush
    @delete_cache.each_key do
      |key|
      @dbm.delete(key)
    end
    
    for key, value in @write_cache
      @dbm[key] = Marshal.dump(value)
    end
    @write_cache.clear
  end
  private :flush

  def close(opt = CLEAR_READ_CACHE)
    @mode = nil
    flush
    @read_cache.clear unless opt == HOLD_READ_CACHE
    @dbm.close
    @dbm = nil

    @transaction_mode = nil
    unusable_methods
  end
  private :close

  def close_with_no_flush
    @mode = nil
    @read_cache = nil
    @write_cache = nil
    @delete_cache = nil

    @dbm.close
    @dbm = nil

    @transaction_mode = nil
    unusable_methods
  end
  private :close_with_no_flush

  
  #---------------------------------------
  #
  # Transaction  -
  #
  #-----------------------------------------------------------
  class Transaction

    extend Exception2MessageMapper
    def_exception :ErrNoStartedTransaction, "トランザクションが開始されていません."
    def_exception :ErrClosedTransaction, "トランザクションはすでに終了しています."

    NO_START = :ObjectDBM__TXN_NO_START
    START = :ObjectDBM__TXN_START
    ABORTING = :ObjectDBM__TXN_ABORTING
    COMMITING = :ObjectDBM__TXN_COMMITING
    COMMITED = :ObjectDBM__TXN_COMMITED
    ABORTED = :ObjectDBM__TXN_ABORTED

    def initialize(odbm, m, outer = nil)
      @odbm = odbm
      @mode = m
      @outer = outer

      @status = NO_START
    end

    attr :mode
    attr :outer, true
    attr :read_cache, true
    attr :write_cache, true
    attr :delete_cache, true
  end

  
  #---------------------------------------
  #
  # StaticTransaction  -
  #     ObjectDBM#transaction {...} -- トランザクションの開始
  #	abort			    -- アボート
  #	checkpoint		    -- トランザクションを終了せずにコ
  #				       ミットする
  # トランザクションの動作:
  # commit: ブロックを正常に終了した時(throw/returnを含む)は, その子ト
  # 	    ランザクションを含めてすべてcommitする.
  # fail:   failして終了した時は, その子トランザクションを含めてすべて
  #	    abortする.
  # abort: 明示的にabortした時は, その子トランザクションを含めすべて
  # 	   abortする.
  #
  #-----------------------------------------------------------
  class StaticTransaction < Transaction
    ABORT_LABEL = "ObjectDBM__TXN_ABORT_LABEL"

    def initialize(odbm, m, outer)
      super
    end

    def transaction
      @status = START
      begin
	txn, value = catch(ABORT_LABEL){[nil, yield(@current_transaction)]}
	if txn
	  @status = ABORTING
	  unless txn.equal?(self)
	    throw ABORT_LABEL, [txn, value]
	  end
	end
	value
      rescue
	# 例外が発生した時
	@status = ABORTING
	fail

      ensure
	case @status
	when NO_START
	  Transaction.fail ErrNoStartedTransaction

	when START
	  @status = COMMITED
	  @odbm.commit(self)

	when ABORTING
	  @status = ABORTED
	  @odbm.abort(self)

	when ABORTED, COMMITED
	  
	  Transactoin.fail ErrClosedTransaction
	end
      end
    end
      
    def abort(value = nil)
      throw ABORT_LABEL, [self, value]
    end
    public :abort

    def checkpoint
      case @status
      when START
	@odbm.flush(txn)
      when COMMITED, ABORTED
	Transaction.fail ErrClosedTransaction
      end
    end

  end

  
  #---------------------------------------
  #
  # DynamicTransaction  -
  #     ObjectDBM#transaction	-- トランザクションの開始
  #	abort			-- アボート
  #	checkpoint		-- トランザクションを終了せずにコミッ
  #				   トする.
  #     commit			-- トランザクションをコミットして終了
  #     			   する.
  # 
  # 入れ子トランザクションの時の動作:
  # commit: 指定のトランザクションの子トランザクションをすべてコミット
  # 	    する. 
  # abort:  指定のトランザクションの子トランザクションをすべてアボート
  # 	    トする. 
  #
  #-----------------------------------------------------------
  class DynamicTransaction < Transaction
    def start
      @status = START
    end

    def commit
      case @status
      when START
	txn = @odbm.current_transaction
	while (txn.equal?(self))
	  @status = COMMITED
	  txn = txn.outer
	end
	@odbm.commit(self)
      when COMMITED, ABORTED
	Transaction.fail ErrClosedTransaction
      end
    end

    def checkpoint
      case @status
      when START
	@odbm.flush(self)
      when COMMITED, ABORTED
	Transaction.fail ErrClosedTransaction
      end
    end

    def abort
      case @status
      when START
	txn = @odbm.current_transaction
	until(txn.equal?(self))
	  txn.status = ABORTED
	  txn = txn.outer
	end
	@status = ABORTED

	@odbm.abort(self)
      when COMMITED, ABORTED
	Transaction.fail ErrClosedTransaction
      end
    end
    public :abort
  end

end
