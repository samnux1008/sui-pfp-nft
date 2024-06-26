module pfp_nft::pfp_nft {

  use std::vector;
  use sui::url::{Self, Url};
  use std::string::{utf8, String};
  use sui::object::{Self, UID, ID};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::coin::{Self, Coin};
  use sui::sui::SUI;
  // use sui::balance::{Self, Balance};
  use sui::event;
  use sui::package;
  use sui::display;

  const EInsufficientPayment: u64 = 11;
  const ECallerNotOwner: u64 = 12;
  const EZeroCount:u64 = 13;
 
  // A simple NFT that can be minted by anyone
  struct NFT has key, store {
    id: UID, 
    tokenId: u64,
    name: String, 
    type: String,
    description: String,
    url: Url,
    image_url: Url,
    link: Url,
    metadata: Url,
  }

  struct PFP_NFT has drop {}

  struct Owner has store, copy, drop {
    tokenId: u64,
    owner: address
  }

  struct Minted has copy, drop {
    id: ID,
    to: address,
    tokenId: u64,
    name: String,
    uri: Url,
    image: Url,
    mimeType: String,
    timestamp: u64
  }

  struct MintHistory has store, copy, drop {
    to: address,
    tokenId: u64,
    name: String,
    uri: Url,
    image: Url,
    mimeType: String,
    timestamp: u64
  }

  struct SettingCap has key {
    id: UID,
    owner: address,
    holder: address,
    minters: vector<address>,
    dev: address,
    price: u64,
    passNft: address,
    devPercent: u64,
    idCounter: u64,
    history: vector<MintHistory>,
    uris: vector<Url>,
    owners: vector<Owner>
  }

  fun init(otw: PFP_NFT, ctx: &mut TxContext) {
    transfer::share_object(SettingCap {
      id: object::new(ctx),
      owner: tx_context::sender(ctx),
      holder: tx_context::sender(ctx),
      minters: vector[],
      dev: tx_context::sender(ctx),
      price: 0,
      passNft: @0x0,
      devPercent: 1000,
      idCounter: 0,
      history: vector[],
      uris: vector[],
      owners: vector[]
    });

    let keys = vector[
      utf8(b"name"),
      utf8(b"description"),
      utf8(b"image_url"),
      utf8(b"link")
    ];

    let values = vector[
      utf8(b"{name}"),
      utf8(b"{description}"),
      utf8(b"{url}"),
      utf8(b"{link}"),
    ];

     // Claim the `Publisher` for the package!
    let publisher = package::claim(otw, ctx);

    // Get a new `Display` object for the `NFT` type.
    let display = display::new_with_fields<NFT>(
        &publisher, keys, values, ctx
    );

    // Commit first version of `Display` to apply changes.
    display::update_version(&mut display);

    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_transfer(display, tx_context::sender(ctx));
  }

  public entry fun transfer_ownership(
    owner: address,
    setting: &mut SettingCap,
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    assert!(setting.owner == sender, ECallerNotOwner);

    setting.owner = owner;
  }

  public entry fun set_minter(
    minter: address, 
    flag: bool,
    setting: &mut SettingCap, 
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    assert!(setting.owner == sender, ECallerNotOwner);

    let (exist, index) = vector::index_of(&setting.minters, &minter);
    
    if (exist == true && flag == false) {
      vector::remove(&mut setting.minters, index);
    };

    if (exist == false && flag == true) {
      vector::push_back(&mut setting.minters, minter);
    }
  }

  public entry fun set_price(
    price: u64,
    setting: &mut SettingCap, 
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    assert!(setting.owner == sender, ECallerNotOwner);

    setting.price = price;
  }

  public entry fun set_pass_nft(
    pass: address,
    setting: &mut SettingCap, 
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    assert!(setting.owner == sender, ECallerNotOwner);

    setting.passNft = pass;
  }

  public entry fun set_owner_wallet(
    wallet: address,
    setting: &mut SettingCap, 
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    assert!(setting.owner == sender, ECallerNotOwner);

    setting.holder = wallet;
  }

  public entry fun set_dev_wallet(
    wallet: address,
    setting: &mut SettingCap, 
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    assert!(setting.owner == sender, ECallerNotOwner);

    setting.dev = wallet;
  }

  public entry fun set_dev_percent(
    percent: u64,
    setting: &mut SettingCap, 
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    assert!(setting.owner == sender, ECallerNotOwner);

    setting.devPercent = percent;
  }

  public entry fun set_token_uri(
    tokenId: u64,
    uri: vector<u8>,
    setting: &mut SettingCap, 
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    assert!(setting.owner == sender, ECallerNotOwner);

    let oldUri = vector::borrow_mut(&mut setting.uris, tokenId);
    *oldUri = url::new_unsafe_from_bytes(uri);
  }

   // create and mint a new NFT
  public entry fun mint(
    name: vector<u8>, 
    type: vector<u8>, 
    desc: vector<u8>,
    url: vector<u8>, 
    link: vector<u8>,
    meta: vector<u8>,
    count: u64, 
    payment: Coin<SUI>, 
    setting: &mut SettingCap, 
    ctx: &mut TxContext
  ) {
    assert!(count > 0, EZeroCount);
    let sender = tx_context::sender(ctx);

    // if (vector::contains(&setting.minters, &sender) || sender == setting.owner) {
    //   transfer::public_transfer(payment, sender); 
    // } else {
    //   let totalPrice = setting.price * count;
    //   assert!(coin::value(&payment) == totalPrice, EInsufficientPayment);
    //   // let coin_balance = coin::balance_mut(&mut payment);
    //   let feeAmount = totalPrice * setting.devPercent / 10000;
    //   let fee = coin::split(&mut payment, feeAmount, ctx);
    //   let paid = coin::split(&mut payment, totalPrice - feeAmount, ctx);
    //   transfer::public_transfer(paid, setting.holder);
    //   transfer::public_transfer(fee, setting.dev);
    // };

    // if (!vector::contains(&setting.minters, &sender) && sender != setting.owner) {
      let totalPrice = setting.price * count;
      assert!(coin::value(&payment) == totalPrice, EInsufficientPayment);
      let feeAmount = totalPrice * setting.devPercent / 10000;
      let fee = coin::split(&mut payment, feeAmount, ctx);
      transfer::public_transfer(fee, setting.dev);
      transfer::public_transfer(payment, setting.holder);
    // };

    let minted = 0;
    loop {
      if (minted == count) break;

      let newTokenId = setting.idCounter + minted;

      let nft = NFT {
        id: object::new(ctx),
        tokenId: newTokenId,
        name: utf8(name),
        type: utf8(type),
        description: utf8(desc),
        url: url::new_unsafe_from_bytes(url),
        image_url: url::new_unsafe_from_bytes(url),
        link: url::new_unsafe_from_bytes(link),
        metadata: url::new_unsafe_from_bytes(meta)
      };

      event::emit(Minted {
        id: object::uid_to_inner(&nft.id),
        to: sender,
        tokenId: nft.tokenId,
        name: nft.name,
        uri: nft.url,
        image: nft.link,
        mimeType: nft.type,
        timestamp: tx_context::epoch(ctx)
      });

      vector::push_back(&mut setting.history, MintHistory {
        to: sender,
        tokenId: nft.tokenId,
        name: nft.name,
        uri: nft.url,
        image: nft.link,
        mimeType: nft.type,
        timestamp: tx_context::epoch(ctx)
      });

      vector::push_back(&mut setting.uris, nft.url);

      vector::push_back(&mut setting.owners, Owner {
        tokenId: nft.tokenId,
        owner: sender
      });

      // transfer the NFT to the caller
      transfer::public_transfer(nft, sender);

      minted = minted + 1;
    };
    setting.idCounter = setting.idCounter + minted;
  }

  // transfer an NFT to another address
  public entry fun transfer(nft: NFT, recipient: address, setting: &mut SettingCap, ctx: &mut TxContext) {
    let counter = 0;
    loop {
      if (counter > setting.idCounter) break;
      let owner = vector::borrow_mut(&mut setting.owners, counter);
      if (owner.owner == tx_context::sender(ctx)) {
        *owner = Owner {
          tokenId: counter,
          owner: recipient
        };
      };
      
      counter = counter + 1;
    };

    transfer::transfer(nft, recipient);
  }

  public fun get_history(setting: &SettingCap): vector<MintHistory> {
    setting.history
  }

  public fun token_uri(setting: &mut SettingCap, tokenId: u64): &Url {
    vector::borrow(&setting.uris, tokenId)
  }

  public fun get_all_tokens(setting: &mut SettingCap, account: address): vector<u64> {
    let counter = 0;
    let tokens = vector::empty<u64>();
    loop {
      if (counter > setting.idCounter) break;
      let owner = vector::borrow(&setting.owners, counter);
      if (owner.owner == account) {
        vector::push_back(&mut tokens, counter);
      };
      
      counter = counter + 1;
    };
    return tokens
  }
}