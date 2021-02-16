from typing import Optional

from .signature import FIELD_PRIME, pedersen_hash


def get_msg(
        instruction_type: int, vault0: int, vault1: int, amount0: int, amount1: int, token0: int,
        token1_or_pub_key: int, nonce: int, expiration_timestamp: int,
        hash=pedersen_hash, condition: Optional[int] = None) -> int:
    """
    Creates a message to sign on.
    """
    packed_message = instruction_type
    packed_message = packed_message * 2**31 + vault0
    packed_message = packed_message * 2**31 + vault1
    packed_message = packed_message * 2**63 + amount0
    packed_message = packed_message * 2**63 + amount1
    packed_message = packed_message * 2**31 + nonce
    packed_message = packed_message * 2**22 + expiration_timestamp
    if condition is not None:
        # A message representing a conditional transfer. The condition is interpreted by the
        # application.
        return hash(hash(hash(token0, token1_or_pub_key), condition), packed_message)

    return hash(hash(token0, token1_or_pub_key), packed_message)


def get_limit_order_msg(
        vault_sell: int, vault_buy: int, amount_sell: int, amount_buy: int, token_sell: int,
        token_buy: int, nonce: int, expiration_timestamp: int,
        hash=pedersen_hash) -> int:
    """
    party_a sells amount_sell coins of token_sell from vault_sell.
    party_a buys amount_buy coins of token_buy into vault_buy.
    """
    assert 0 <= vault_sell < 2**31
    assert 0 <= vault_buy < 2**31
    assert 0 <= amount_sell < 2**63
    assert 0 <= amount_buy < 2**63
    assert 0 <= token_sell < FIELD_PRIME
    assert 0 <= token_buy < FIELD_PRIME
    assert 0 <= nonce < 2**31
    assert 0 <= expiration_timestamp < 2**22

    instruction_type = 0
    return get_msg(
        instruction_type, vault_sell, vault_buy, amount_sell, amount_buy, token_sell, token_buy,
        nonce, expiration_timestamp, hash=hash)


def get_transfer_msg(
        amount: int, nonce: int, sender_vault_id: int, token: int, receiver_vault_id: int,
        receiver_public_key: int, expiration_timestamp: int,
        hash=pedersen_hash, condition: Optional[int] = None) -> int:
    """
    Transfer `amount` of `token` from `sender_vault_id` to `receiver_vault_id`.
    The transfer is conditional only if `condition` is given.
    """
    assert 0 <= sender_vault_id < 2**31
    assert 0 <= receiver_vault_id < 2**31
    assert 0 <= amount < 2**63
    assert 0 <= token < FIELD_PRIME
    assert 0 <= receiver_public_key < FIELD_PRIME
    assert 0 <= nonce < 2**31
    assert 0 <= expiration_timestamp < 2**22

    TRANSFER = 1
    CONDITIONAL_TRANSFER = 2
    instruction_type = CONDITIONAL_TRANSFER if condition else TRANSFER
    assert condition is None or 0 <= condition < FIELD_PRIME

    return get_msg(
        instruction_type, sender_vault_id, receiver_vault_id, amount, 0, token, receiver_public_key,
        nonce, expiration_timestamp, hash=hash, condition=condition)


#####################################################################################
# get_price_msg: gets as input:                                                     #
#       oracle: a 40-bit number, describes the oracle (i.e hex encoding of "Maker") #
#       price: a 120-bit number                                                     #
#       asset: a 128-bit number                                                     #
#       timestamp: a 32 bit number, represents seconds since epoch                  #
# outputs a number which is less than FIELD_PRIME, which can be used as data        #
# to sign on in the sign method. This number is obtained by applying pedersen       #
# on the following two numbers:                                                     #
#                                                                                   #
# first number:                                                                     #
# --------------------------------------------------------------------------------- #
# | 0 (84 bits)       | asset_name (128 bits)         |   oracle_name (40 bits)   | #
# --------------------------------------------------------------------------------- #
#                                                                                   #
# second number:                                                                    #
# --------------------------------------------------------------------------------- #
# | 0 (100 bits)         | price (120 bits)             |   timestamp (32 bits)   | #
# --------------------------------------------------------------------------------- #
#                                                                                   #
#####################################################################################


def get_price_msg(oracle_name: int, asset_pair: int, timestamp: int, price: int):
    assert 0 <= oracle_name < 2**40
    assert 0 <= asset_pair < 2**128
    assert 0 <= timestamp < 2**32
    assert 0 <= price < 2**120

    # The first number to hash is the oracle name (Maker) and the asset name.
    first_number = (asset_pair << 40) + oracle_name

    # The second number is timestamp in the 32 LSB, then the price.
    second_number = (price << 32) + timestamp

    return pedersen_hash(first_number, second_number)
