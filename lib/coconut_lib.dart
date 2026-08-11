library coconut_lib;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:bech32m_i/bech32m_i.dart' as bech32m;
import 'package:decimal/decimal.dart';
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

import 'src/cryptography/mnemonic_wordlist/english.dart' as english_words;

export 'src/cryptography/mnemonic_wordlist/english.dart';

part 'src/exception/coconut_exception.dart';
part 'src/transaction/partially_signed_bitcoin_transaction.dart';
part 'src/script/script.dart';
part 'src/script/script_operation_code.dart';
part 'src/script/script_public_key.dart';
part 'src/script/script_signature.dart';
part 'src/transaction/signature.dart';
part 'src/transaction/transaction.dart';
part 'src/transaction/transaction_input.dart';
part 'src/transaction/transaction_output.dart';
part 'src/script/multisignature_script.dart';
part 'src/script/inheritance_policy.dart';
part 'src/script/policy.dart';
part 'src/wallet/network_type.dart';
part 'src/wallet/address_type.dart';
part 'src/wallet/bitcoin_secure_multisig_setup.dart';
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
part 'src/wallet/taproot_wallet_base.dart';
part 'src/wallet/taproot_vault.dart';
part 'src/wallet/taproot_wallet.dart';
part 'src/wallet/unspent_transaction_output.dart';
part 'src/wallet/wallet_base.dart';
part 'src/wallet/wallet_utility.dart';
part 'src/cryptography/converter.dart';
part 'src/cryptography/elliptic_curve_cryptography.dart';
part 'src/cryptography/hash.dart';
part 'src/cryptography/codec.dart';
part 'src/script/miniscript.dart';
