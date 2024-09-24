/// The coconut_lib is a development tool for mobile air gap Bitcoin wallets. It is written in [`Dart`](https://dart.dev/).
/// Coconut Vault and Coconut Wallet were created using this library.
///
/// This library provides essential functionality for Bitcoin wallet development:
/// - Hierarchical Deterministic (HD) wallet implementation
/// - Transaction creation, signing, and broadcasting
/// - Address generation and management
/// - Network communication with Bitcoin nodes
/// - Support for Electrum protocol and Mempool interaction
/// - Cryptographic utilities and security features
/// - Air-gapped operations for enhanced security
/// - Data persistence and management
///
library coconut_lib;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:bech32m_i/bech32m_i.dart' as bech32m;
import 'package:convert/convert.dart';
import 'package:decimal/decimal.dart';
import 'package:hex/hex.dart';
import 'package:http/http.dart';

import 'src/network/electrum/electrum_res_types.dart';
import 'src/objectbox/objectbox.g.dart';
import 'src/objectbox/objectbox_entity.dart';
import 'src/utils/base58.dart';
import 'src/utils/converter.dart';
import 'src/utils/ecc.dart' as ecc;
import 'src/utils/enum.dart';
import 'src/utils/error.dart';
import 'src/utils/hash.dart';
import 'src/utils/pbkdf2.dart';
import 'src/utils/result_type.dart';
import 'src/utils/varints.dart';
import 'src/utils/wif.dart' as wif;
import 'src/utils/wordlists/english.dart' as english_words;

export 'src/objectbox/objectbox_entity.dart';
export 'src/utils/enum.dart';
export 'src/utils/error.dart';
export 'src/utils/result_type.dart';
export 'src/utils/wordlists/english.dart';

part 'src/network/bitcoin_network.dart';
part 'src/network/block.dart';
part 'src/network/electrum/electrum_api.dart';
part 'src/network/electrum/electrum_client.dart';
part 'src/network/electrum/electrum_req_types.dart';
part 'src/network/mempool/mempool_api.dart';
part 'src/network/mempool/mempool_res_type.dart';
part 'src/network/network.dart';
part 'src/network/node_connector.dart';
part 'src/network/socket/socket_factory.dart';
part 'src/network/socket/socket_manager.dart';
part 'src/network/wallet_fetch_result.dart';
part 'src/objectbox/repository.dart';
part 'src/transaction/partially_signed_bitcoin_transaction.dart';
part 'src/transaction/script.dart';
part 'src/transaction/script_public_key.dart';
part 'src/transaction/script_signature.dart';
part 'src/transaction/transaction.dart';
part 'src/transaction/transaction_input.dart';
part 'src/transaction/transaction_output.dart';
part 'src/utils/repository_util.dart';
part 'src/utils/unit.dart';
part 'src/wallet/address.dart';
part 'src/wallet/address_book.dart';
part 'src/wallet/address_type.dart';
part 'src/wallet/balance.dart';
part 'src/wallet/descriptor.dart';
part 'src/wallet/extended_public_key.dart';
part 'src/wallet/hierarchical_deterministic_wallet.dart';
part 'src/wallet/key_store.dart';
part 'src/wallet/multisignature_vault.dart';
part 'src/wallet/multisignature_wallet.dart';
part 'src/wallet/multisignature_wallet_base.dart';
part 'src/wallet/seed.dart';
part 'src/wallet/single_signature_vault.dart';
part 'src/wallet/single_signature_wallet.dart';
part 'src/wallet/single_signature_wallet_base.dart';
part 'src/wallet/transfer.dart';
part 'src/wallet/unspent_transaction_output.dart';
part 'src/wallet/vault_feature.dart';
part 'src/wallet/wallet_base.dart';
part 'src/wallet/wallet_feature.dart';
part 'src/wallet/wallet_utility.dart';
