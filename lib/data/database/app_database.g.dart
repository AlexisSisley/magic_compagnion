// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CollectionCardsTable extends CollectionCards
    with TableInfo<$CollectionCardsTable, DbCollectionCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scryfallIdMeta = const VerificationMeta(
    'scryfallId',
  );
  @override
  late final GeneratedColumn<String> scryfallId = GeneratedColumn<String>(
    'scryfall_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _proxyQuantityMeta = const VerificationMeta(
    'proxyQuantity',
  );
  @override
  late final GeneratedColumn<int> proxyQuantity = GeneratedColumn<int>(
    'proxy_quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFoilMeta = const VerificationMeta('isFoil');
  @override
  late final GeneratedColumn<bool> isFoil = GeneratedColumn<bool>(
    'is_foil',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_foil" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scryfallId,
    name,
    quantity,
    proxyQuantity,
    isFoil,
    tags,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbCollectionCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scryfall_id')) {
      context.handle(
        _scryfallIdMeta,
        scryfallId.isAcceptableOrUnknown(data['scryfall_id']!, _scryfallIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scryfallIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('proxy_quantity')) {
      context.handle(
        _proxyQuantityMeta,
        proxyQuantity.isAcceptableOrUnknown(
          data['proxy_quantity']!,
          _proxyQuantityMeta,
        ),
      );
    }
    if (data.containsKey('is_foil')) {
      context.handle(
        _isFoilMeta,
        isFoil.isAcceptableOrUnknown(data['is_foil']!, _isFoilMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbCollectionCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbCollectionCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      scryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scryfall_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      proxyQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}proxy_quantity'],
      )!,
      isFoil: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_foil'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
    );
  }

  @override
  $CollectionCardsTable createAlias(String alias) {
    return $CollectionCardsTable(attachedDatabase, alias);
  }
}

class DbCollectionCard extends DataClass
    implements Insertable<DbCollectionCard> {
  final int id;
  final String scryfallId;
  final String name;
  final int quantity;
  final int proxyQuantity;
  final bool isFoil;
  final String tags;
  const DbCollectionCard({
    required this.id,
    required this.scryfallId,
    required this.name,
    required this.quantity,
    required this.proxyQuantity,
    required this.isFoil,
    required this.tags,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scryfall_id'] = Variable<String>(scryfallId);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<int>(quantity);
    map['proxy_quantity'] = Variable<int>(proxyQuantity);
    map['is_foil'] = Variable<bool>(isFoil);
    map['tags'] = Variable<String>(tags);
    return map;
  }

  CollectionCardsCompanion toCompanion(bool nullToAbsent) {
    return CollectionCardsCompanion(
      id: Value(id),
      scryfallId: Value(scryfallId),
      name: Value(name),
      quantity: Value(quantity),
      proxyQuantity: Value(proxyQuantity),
      isFoil: Value(isFoil),
      tags: Value(tags),
    );
  }

  factory DbCollectionCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbCollectionCard(
      id: serializer.fromJson<int>(json['id']),
      scryfallId: serializer.fromJson<String>(json['scryfallId']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<int>(json['quantity']),
      proxyQuantity: serializer.fromJson<int>(json['proxyQuantity']),
      isFoil: serializer.fromJson<bool>(json['isFoil']),
      tags: serializer.fromJson<String>(json['tags']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scryfallId': serializer.toJson<String>(scryfallId),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<int>(quantity),
      'proxyQuantity': serializer.toJson<int>(proxyQuantity),
      'isFoil': serializer.toJson<bool>(isFoil),
      'tags': serializer.toJson<String>(tags),
    };
  }

  DbCollectionCard copyWith({
    int? id,
    String? scryfallId,
    String? name,
    int? quantity,
    int? proxyQuantity,
    bool? isFoil,
    String? tags,
  }) => DbCollectionCard(
    id: id ?? this.id,
    scryfallId: scryfallId ?? this.scryfallId,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    proxyQuantity: proxyQuantity ?? this.proxyQuantity,
    isFoil: isFoil ?? this.isFoil,
    tags: tags ?? this.tags,
  );
  DbCollectionCard copyWithCompanion(CollectionCardsCompanion data) {
    return DbCollectionCard(
      id: data.id.present ? data.id.value : this.id,
      scryfallId: data.scryfallId.present
          ? data.scryfallId.value
          : this.scryfallId,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      proxyQuantity: data.proxyQuantity.present
          ? data.proxyQuantity.value
          : this.proxyQuantity,
      isFoil: data.isFoil.present ? data.isFoil.value : this.isFoil,
      tags: data.tags.present ? data.tags.value : this.tags,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbCollectionCard(')
          ..write('id: $id, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('proxyQuantity: $proxyQuantity, ')
          ..write('isFoil: $isFoil, ')
          ..write('tags: $tags')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, scryfallId, name, quantity, proxyQuantity, isFoil, tags);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbCollectionCard &&
          other.id == this.id &&
          other.scryfallId == this.scryfallId &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.proxyQuantity == this.proxyQuantity &&
          other.isFoil == this.isFoil &&
          other.tags == this.tags);
}

class CollectionCardsCompanion extends UpdateCompanion<DbCollectionCard> {
  final Value<int> id;
  final Value<String> scryfallId;
  final Value<String> name;
  final Value<int> quantity;
  final Value<int> proxyQuantity;
  final Value<bool> isFoil;
  final Value<String> tags;
  const CollectionCardsCompanion({
    this.id = const Value.absent(),
    this.scryfallId = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.proxyQuantity = const Value.absent(),
    this.isFoil = const Value.absent(),
    this.tags = const Value.absent(),
  });
  CollectionCardsCompanion.insert({
    this.id = const Value.absent(),
    required String scryfallId,
    required String name,
    this.quantity = const Value.absent(),
    this.proxyQuantity = const Value.absent(),
    this.isFoil = const Value.absent(),
    this.tags = const Value.absent(),
  }) : scryfallId = Value(scryfallId),
       name = Value(name);
  static Insertable<DbCollectionCard> custom({
    Expression<int>? id,
    Expression<String>? scryfallId,
    Expression<String>? name,
    Expression<int>? quantity,
    Expression<int>? proxyQuantity,
    Expression<bool>? isFoil,
    Expression<String>? tags,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scryfallId != null) 'scryfall_id': scryfallId,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (proxyQuantity != null) 'proxy_quantity': proxyQuantity,
      if (isFoil != null) 'is_foil': isFoil,
      if (tags != null) 'tags': tags,
    });
  }

  CollectionCardsCompanion copyWith({
    Value<int>? id,
    Value<String>? scryfallId,
    Value<String>? name,
    Value<int>? quantity,
    Value<int>? proxyQuantity,
    Value<bool>? isFoil,
    Value<String>? tags,
  }) {
    return CollectionCardsCompanion(
      id: id ?? this.id,
      scryfallId: scryfallId ?? this.scryfallId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      proxyQuantity: proxyQuantity ?? this.proxyQuantity,
      isFoil: isFoil ?? this.isFoil,
      tags: tags ?? this.tags,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scryfallId.present) {
      map['scryfall_id'] = Variable<String>(scryfallId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (proxyQuantity.present) {
      map['proxy_quantity'] = Variable<int>(proxyQuantity.value);
    }
    if (isFoil.present) {
      map['is_foil'] = Variable<bool>(isFoil.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionCardsCompanion(')
          ..write('id: $id, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('proxyQuantity: $proxyQuantity, ')
          ..write('isFoil: $isFoil, ')
          ..write('tags: $tags')
          ..write(')'))
        .toString();
  }
}

class $DecksTable extends Decks with TableInfo<$DecksTable, DbDeck> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Standard'),
  );
  static const VerificationMeta _commanderScryfallIdMeta =
      const VerificationMeta('commanderScryfallId');
  @override
  late final GeneratedColumn<String> commanderScryfallId =
      GeneratedColumn<String>(
        'commander_scryfall_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _commanderSecondaryScryfallIdMeta =
      const VerificationMeta('commanderSecondaryScryfallId');
  @override
  late final GeneratedColumn<String> commanderSecondaryScryfallId =
      GeneratedColumn<String>(
        'commander_secondary_scryfall_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _colorsMeta = const VerificationMeta('colors');
  @override
  late final GeneratedColumn<String> colors = GeneratedColumn<String>(
    'colors',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    format,
    commanderScryfallId,
    commanderSecondaryScryfallId,
    colors,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbDeck> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('commander_scryfall_id')) {
      context.handle(
        _commanderScryfallIdMeta,
        commanderScryfallId.isAcceptableOrUnknown(
          data['commander_scryfall_id']!,
          _commanderScryfallIdMeta,
        ),
      );
    }
    if (data.containsKey('commander_secondary_scryfall_id')) {
      context.handle(
        _commanderSecondaryScryfallIdMeta,
        commanderSecondaryScryfallId.isAcceptableOrUnknown(
          data['commander_secondary_scryfall_id']!,
          _commanderSecondaryScryfallIdMeta,
        ),
      );
    }
    if (data.containsKey('colors')) {
      context.handle(
        _colorsMeta,
        colors.isAcceptableOrUnknown(data['colors']!, _colorsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbDeck map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbDeck(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      commanderScryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_scryfall_id'],
      ),
      commanderSecondaryScryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_secondary_scryfall_id'],
      ),
      colors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colors'],
      )!,
    );
  }

  @override
  $DecksTable createAlias(String alias) {
    return $DecksTable(attachedDatabase, alias);
  }
}

class DbDeck extends DataClass implements Insertable<DbDeck> {
  final String id;
  final String name;
  final String format;
  final String? commanderScryfallId;
  final String? commanderSecondaryScryfallId;
  final String colors;
  const DbDeck({
    required this.id,
    required this.name,
    required this.format,
    this.commanderScryfallId,
    this.commanderSecondaryScryfallId,
    required this.colors,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || commanderScryfallId != null) {
      map['commander_scryfall_id'] = Variable<String>(commanderScryfallId);
    }
    if (!nullToAbsent || commanderSecondaryScryfallId != null) {
      map['commander_secondary_scryfall_id'] = Variable<String>(
        commanderSecondaryScryfallId,
      );
    }
    map['colors'] = Variable<String>(colors);
    return map;
  }

  DecksCompanion toCompanion(bool nullToAbsent) {
    return DecksCompanion(
      id: Value(id),
      name: Value(name),
      format: Value(format),
      commanderScryfallId: commanderScryfallId == null && nullToAbsent
          ? const Value.absent()
          : Value(commanderScryfallId),
      commanderSecondaryScryfallId:
          commanderSecondaryScryfallId == null && nullToAbsent
          ? const Value.absent()
          : Value(commanderSecondaryScryfallId),
      colors: Value(colors),
    );
  }

  factory DbDeck.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbDeck(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      format: serializer.fromJson<String>(json['format']),
      commanderScryfallId: serializer.fromJson<String?>(
        json['commanderScryfallId'],
      ),
      commanderSecondaryScryfallId: serializer.fromJson<String?>(
        json['commanderSecondaryScryfallId'],
      ),
      colors: serializer.fromJson<String>(json['colors']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'format': serializer.toJson<String>(format),
      'commanderScryfallId': serializer.toJson<String?>(commanderScryfallId),
      'commanderSecondaryScryfallId': serializer.toJson<String?>(
        commanderSecondaryScryfallId,
      ),
      'colors': serializer.toJson<String>(colors),
    };
  }

  DbDeck copyWith({
    String? id,
    String? name,
    String? format,
    Value<String?> commanderScryfallId = const Value.absent(),
    Value<String?> commanderSecondaryScryfallId = const Value.absent(),
    String? colors,
  }) => DbDeck(
    id: id ?? this.id,
    name: name ?? this.name,
    format: format ?? this.format,
    commanderScryfallId: commanderScryfallId.present
        ? commanderScryfallId.value
        : this.commanderScryfallId,
    commanderSecondaryScryfallId: commanderSecondaryScryfallId.present
        ? commanderSecondaryScryfallId.value
        : this.commanderSecondaryScryfallId,
    colors: colors ?? this.colors,
  );
  DbDeck copyWithCompanion(DecksCompanion data) {
    return DbDeck(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      format: data.format.present ? data.format.value : this.format,
      commanderScryfallId: data.commanderScryfallId.present
          ? data.commanderScryfallId.value
          : this.commanderScryfallId,
      commanderSecondaryScryfallId: data.commanderSecondaryScryfallId.present
          ? data.commanderSecondaryScryfallId.value
          : this.commanderSecondaryScryfallId,
      colors: data.colors.present ? data.colors.value : this.colors,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbDeck(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('commanderScryfallId: $commanderScryfallId, ')
          ..write(
            'commanderSecondaryScryfallId: $commanderSecondaryScryfallId, ',
          )
          ..write('colors: $colors')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    format,
    commanderScryfallId,
    commanderSecondaryScryfallId,
    colors,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbDeck &&
          other.id == this.id &&
          other.name == this.name &&
          other.format == this.format &&
          other.commanderScryfallId == this.commanderScryfallId &&
          other.commanderSecondaryScryfallId ==
              this.commanderSecondaryScryfallId &&
          other.colors == this.colors);
}

class DecksCompanion extends UpdateCompanion<DbDeck> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> format;
  final Value<String?> commanderScryfallId;
  final Value<String?> commanderSecondaryScryfallId;
  final Value<String> colors;
  final Value<int> rowid;
  const DecksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.format = const Value.absent(),
    this.commanderScryfallId = const Value.absent(),
    this.commanderSecondaryScryfallId = const Value.absent(),
    this.colors = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DecksCompanion.insert({
    required String id,
    required String name,
    this.format = const Value.absent(),
    this.commanderScryfallId = const Value.absent(),
    this.commanderSecondaryScryfallId = const Value.absent(),
    this.colors = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<DbDeck> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? format,
    Expression<String>? commanderScryfallId,
    Expression<String>? commanderSecondaryScryfallId,
    Expression<String>? colors,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (format != null) 'format': format,
      if (commanderScryfallId != null)
        'commander_scryfall_id': commanderScryfallId,
      if (commanderSecondaryScryfallId != null)
        'commander_secondary_scryfall_id': commanderSecondaryScryfallId,
      if (colors != null) 'colors': colors,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DecksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? format,
    Value<String?>? commanderScryfallId,
    Value<String?>? commanderSecondaryScryfallId,
    Value<String>? colors,
    Value<int>? rowid,
  }) {
    return DecksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      format: format ?? this.format,
      commanderScryfallId: commanderScryfallId ?? this.commanderScryfallId,
      commanderSecondaryScryfallId:
          commanderSecondaryScryfallId ?? this.commanderSecondaryScryfallId,
      colors: colors ?? this.colors,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (commanderScryfallId.present) {
      map['commander_scryfall_id'] = Variable<String>(
        commanderScryfallId.value,
      );
    }
    if (commanderSecondaryScryfallId.present) {
      map['commander_secondary_scryfall_id'] = Variable<String>(
        commanderSecondaryScryfallId.value,
      );
    }
    if (colors.present) {
      map['colors'] = Variable<String>(colors.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('commanderScryfallId: $commanderScryfallId, ')
          ..write(
            'commanderSecondaryScryfallId: $commanderSecondaryScryfallId, ',
          )
          ..write('colors: $colors, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeckCardsTable extends DeckCards
    with TableInfo<$DeckCardsTable, DbDeckCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES decks (id)',
    ),
  );
  static const VerificationMeta _boardMeta = const VerificationMeta('board');
  @override
  late final GeneratedColumn<String> board = GeneratedColumn<String>(
    'board',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scryfallIdMeta = const VerificationMeta(
    'scryfallId',
  );
  @override
  late final GeneratedColumn<String> scryfallId = GeneratedColumn<String>(
    'scryfall_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _proxyQuantityMeta = const VerificationMeta(
    'proxyQuantity',
  );
  @override
  late final GeneratedColumn<int> proxyQuantity = GeneratedColumn<int>(
    'proxy_quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFoilMeta = const VerificationMeta('isFoil');
  @override
  late final GeneratedColumn<bool> isFoil = GeneratedColumn<bool>(
    'is_foil',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_foil" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deckId,
    board,
    scryfallId,
    name,
    quantity,
    proxyQuantity,
    isFoil,
    tags,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbDeckCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('board')) {
      context.handle(
        _boardMeta,
        board.isAcceptableOrUnknown(data['board']!, _boardMeta),
      );
    } else if (isInserting) {
      context.missing(_boardMeta);
    }
    if (data.containsKey('scryfall_id')) {
      context.handle(
        _scryfallIdMeta,
        scryfallId.isAcceptableOrUnknown(data['scryfall_id']!, _scryfallIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scryfallIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('proxy_quantity')) {
      context.handle(
        _proxyQuantityMeta,
        proxyQuantity.isAcceptableOrUnknown(
          data['proxy_quantity']!,
          _proxyQuantityMeta,
        ),
      );
    }
    if (data.containsKey('is_foil')) {
      context.handle(
        _isFoilMeta,
        isFoil.isAcceptableOrUnknown(data['is_foil']!, _isFoilMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbDeckCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbDeckCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      board: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}board'],
      )!,
      scryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scryfall_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      proxyQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}proxy_quantity'],
      )!,
      isFoil: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_foil'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
    );
  }

  @override
  $DeckCardsTable createAlias(String alias) {
    return $DeckCardsTable(attachedDatabase, alias);
  }
}

class DbDeckCard extends DataClass implements Insertable<DbDeckCard> {
  final int id;
  final String deckId;
  final String board;
  final String scryfallId;
  final String name;
  final int quantity;
  final int proxyQuantity;
  final bool isFoil;
  final String tags;
  const DbDeckCard({
    required this.id,
    required this.deckId,
    required this.board,
    required this.scryfallId,
    required this.name,
    required this.quantity,
    required this.proxyQuantity,
    required this.isFoil,
    required this.tags,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['deck_id'] = Variable<String>(deckId);
    map['board'] = Variable<String>(board);
    map['scryfall_id'] = Variable<String>(scryfallId);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<int>(quantity);
    map['proxy_quantity'] = Variable<int>(proxyQuantity);
    map['is_foil'] = Variable<bool>(isFoil);
    map['tags'] = Variable<String>(tags);
    return map;
  }

  DeckCardsCompanion toCompanion(bool nullToAbsent) {
    return DeckCardsCompanion(
      id: Value(id),
      deckId: Value(deckId),
      board: Value(board),
      scryfallId: Value(scryfallId),
      name: Value(name),
      quantity: Value(quantity),
      proxyQuantity: Value(proxyQuantity),
      isFoil: Value(isFoil),
      tags: Value(tags),
    );
  }

  factory DbDeckCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbDeckCard(
      id: serializer.fromJson<int>(json['id']),
      deckId: serializer.fromJson<String>(json['deckId']),
      board: serializer.fromJson<String>(json['board']),
      scryfallId: serializer.fromJson<String>(json['scryfallId']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<int>(json['quantity']),
      proxyQuantity: serializer.fromJson<int>(json['proxyQuantity']),
      isFoil: serializer.fromJson<bool>(json['isFoil']),
      tags: serializer.fromJson<String>(json['tags']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deckId': serializer.toJson<String>(deckId),
      'board': serializer.toJson<String>(board),
      'scryfallId': serializer.toJson<String>(scryfallId),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<int>(quantity),
      'proxyQuantity': serializer.toJson<int>(proxyQuantity),
      'isFoil': serializer.toJson<bool>(isFoil),
      'tags': serializer.toJson<String>(tags),
    };
  }

  DbDeckCard copyWith({
    int? id,
    String? deckId,
    String? board,
    String? scryfallId,
    String? name,
    int? quantity,
    int? proxyQuantity,
    bool? isFoil,
    String? tags,
  }) => DbDeckCard(
    id: id ?? this.id,
    deckId: deckId ?? this.deckId,
    board: board ?? this.board,
    scryfallId: scryfallId ?? this.scryfallId,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    proxyQuantity: proxyQuantity ?? this.proxyQuantity,
    isFoil: isFoil ?? this.isFoil,
    tags: tags ?? this.tags,
  );
  DbDeckCard copyWithCompanion(DeckCardsCompanion data) {
    return DbDeckCard(
      id: data.id.present ? data.id.value : this.id,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      board: data.board.present ? data.board.value : this.board,
      scryfallId: data.scryfallId.present
          ? data.scryfallId.value
          : this.scryfallId,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      proxyQuantity: data.proxyQuantity.present
          ? data.proxyQuantity.value
          : this.proxyQuantity,
      isFoil: data.isFoil.present ? data.isFoil.value : this.isFoil,
      tags: data.tags.present ? data.tags.value : this.tags,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbDeckCard(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('board: $board, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('proxyQuantity: $proxyQuantity, ')
          ..write('isFoil: $isFoil, ')
          ..write('tags: $tags')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deckId,
    board,
    scryfallId,
    name,
    quantity,
    proxyQuantity,
    isFoil,
    tags,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbDeckCard &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.board == this.board &&
          other.scryfallId == this.scryfallId &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.proxyQuantity == this.proxyQuantity &&
          other.isFoil == this.isFoil &&
          other.tags == this.tags);
}

class DeckCardsCompanion extends UpdateCompanion<DbDeckCard> {
  final Value<int> id;
  final Value<String> deckId;
  final Value<String> board;
  final Value<String> scryfallId;
  final Value<String> name;
  final Value<int> quantity;
  final Value<int> proxyQuantity;
  final Value<bool> isFoil;
  final Value<String> tags;
  const DeckCardsCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.board = const Value.absent(),
    this.scryfallId = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.proxyQuantity = const Value.absent(),
    this.isFoil = const Value.absent(),
    this.tags = const Value.absent(),
  });
  DeckCardsCompanion.insert({
    this.id = const Value.absent(),
    required String deckId,
    required String board,
    required String scryfallId,
    required String name,
    this.quantity = const Value.absent(),
    this.proxyQuantity = const Value.absent(),
    this.isFoil = const Value.absent(),
    this.tags = const Value.absent(),
  }) : deckId = Value(deckId),
       board = Value(board),
       scryfallId = Value(scryfallId),
       name = Value(name);
  static Insertable<DbDeckCard> custom({
    Expression<int>? id,
    Expression<String>? deckId,
    Expression<String>? board,
    Expression<String>? scryfallId,
    Expression<String>? name,
    Expression<int>? quantity,
    Expression<int>? proxyQuantity,
    Expression<bool>? isFoil,
    Expression<String>? tags,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (board != null) 'board': board,
      if (scryfallId != null) 'scryfall_id': scryfallId,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (proxyQuantity != null) 'proxy_quantity': proxyQuantity,
      if (isFoil != null) 'is_foil': isFoil,
      if (tags != null) 'tags': tags,
    });
  }

  DeckCardsCompanion copyWith({
    Value<int>? id,
    Value<String>? deckId,
    Value<String>? board,
    Value<String>? scryfallId,
    Value<String>? name,
    Value<int>? quantity,
    Value<int>? proxyQuantity,
    Value<bool>? isFoil,
    Value<String>? tags,
  }) {
    return DeckCardsCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      board: board ?? this.board,
      scryfallId: scryfallId ?? this.scryfallId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      proxyQuantity: proxyQuantity ?? this.proxyQuantity,
      isFoil: isFoil ?? this.isFoil,
      tags: tags ?? this.tags,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (board.present) {
      map['board'] = Variable<String>(board.value);
    }
    if (scryfallId.present) {
      map['scryfall_id'] = Variable<String>(scryfallId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (proxyQuantity.present) {
      map['proxy_quantity'] = Variable<int>(proxyQuantity.value);
    }
    if (isFoil.present) {
      map['is_foil'] = Variable<bool>(isFoil.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckCardsCompanion(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('board: $board, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('proxyQuantity: $proxyQuantity, ')
          ..write('isFoil: $isFoil, ')
          ..write('tags: $tags')
          ..write(')'))
        .toString();
  }
}

class $WishlistsTable extends Wishlists
    with TableInfo<$WishlistsTable, DbWishlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishlistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateCreatedMeta = const VerificationMeta(
    'dateCreated',
  );
  @override
  late final GeneratedColumn<DateTime> dateCreated = GeneratedColumn<DateTime>(
    'date_created',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconScryfallIdMeta = const VerificationMeta(
    'iconScryfallId',
  );
  @override
  late final GeneratedColumn<String> iconScryfallId = GeneratedColumn<String>(
    'icon_scryfall_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, dateCreated, iconScryfallId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wishlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbWishlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('date_created')) {
      context.handle(
        _dateCreatedMeta,
        dateCreated.isAcceptableOrUnknown(
          data['date_created']!,
          _dateCreatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dateCreatedMeta);
    }
    if (data.containsKey('icon_scryfall_id')) {
      context.handle(
        _iconScryfallIdMeta,
        iconScryfallId.isAcceptableOrUnknown(
          data['icon_scryfall_id']!,
          _iconScryfallIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbWishlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbWishlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      dateCreated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_created'],
      )!,
      iconScryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_scryfall_id'],
      ),
    );
  }

  @override
  $WishlistsTable createAlias(String alias) {
    return $WishlistsTable(attachedDatabase, alias);
  }
}

class DbWishlist extends DataClass implements Insertable<DbWishlist> {
  final String id;
  final String name;
  final DateTime dateCreated;
  final String? iconScryfallId;
  const DbWishlist({
    required this.id,
    required this.name,
    required this.dateCreated,
    this.iconScryfallId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['date_created'] = Variable<DateTime>(dateCreated);
    if (!nullToAbsent || iconScryfallId != null) {
      map['icon_scryfall_id'] = Variable<String>(iconScryfallId);
    }
    return map;
  }

  WishlistsCompanion toCompanion(bool nullToAbsent) {
    return WishlistsCompanion(
      id: Value(id),
      name: Value(name),
      dateCreated: Value(dateCreated),
      iconScryfallId: iconScryfallId == null && nullToAbsent
          ? const Value.absent()
          : Value(iconScryfallId),
    );
  }

  factory DbWishlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbWishlist(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      dateCreated: serializer.fromJson<DateTime>(json['dateCreated']),
      iconScryfallId: serializer.fromJson<String?>(json['iconScryfallId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'dateCreated': serializer.toJson<DateTime>(dateCreated),
      'iconScryfallId': serializer.toJson<String?>(iconScryfallId),
    };
  }

  DbWishlist copyWith({
    String? id,
    String? name,
    DateTime? dateCreated,
    Value<String?> iconScryfallId = const Value.absent(),
  }) => DbWishlist(
    id: id ?? this.id,
    name: name ?? this.name,
    dateCreated: dateCreated ?? this.dateCreated,
    iconScryfallId: iconScryfallId.present
        ? iconScryfallId.value
        : this.iconScryfallId,
  );
  DbWishlist copyWithCompanion(WishlistsCompanion data) {
    return DbWishlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      dateCreated: data.dateCreated.present
          ? data.dateCreated.value
          : this.dateCreated,
      iconScryfallId: data.iconScryfallId.present
          ? data.iconScryfallId.value
          : this.iconScryfallId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbWishlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('dateCreated: $dateCreated, ')
          ..write('iconScryfallId: $iconScryfallId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, dateCreated, iconScryfallId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbWishlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.dateCreated == this.dateCreated &&
          other.iconScryfallId == this.iconScryfallId);
}

class WishlistsCompanion extends UpdateCompanion<DbWishlist> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> dateCreated;
  final Value<String?> iconScryfallId;
  final Value<int> rowid;
  const WishlistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.dateCreated = const Value.absent(),
    this.iconScryfallId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WishlistsCompanion.insert({
    required String id,
    required String name,
    required DateTime dateCreated,
    this.iconScryfallId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       dateCreated = Value(dateCreated);
  static Insertable<DbWishlist> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? dateCreated,
    Expression<String>? iconScryfallId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (dateCreated != null) 'date_created': dateCreated,
      if (iconScryfallId != null) 'icon_scryfall_id': iconScryfallId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WishlistsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? dateCreated,
    Value<String?>? iconScryfallId,
    Value<int>? rowid,
  }) {
    return WishlistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      dateCreated: dateCreated ?? this.dateCreated,
      iconScryfallId: iconScryfallId ?? this.iconScryfallId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (dateCreated.present) {
      map['date_created'] = Variable<DateTime>(dateCreated.value);
    }
    if (iconScryfallId.present) {
      map['icon_scryfall_id'] = Variable<String>(iconScryfallId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishlistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('dateCreated: $dateCreated, ')
          ..write('iconScryfallId: $iconScryfallId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WishlistCardsTable extends WishlistCards
    with TableInfo<$WishlistCardsTable, DbWishlistCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishlistCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wishlistIdMeta = const VerificationMeta(
    'wishlistId',
  );
  @override
  late final GeneratedColumn<String> wishlistId = GeneratedColumn<String>(
    'wishlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wishlists (id)',
    ),
  );
  static const VerificationMeta _scryfallIdMeta = const VerificationMeta(
    'scryfallId',
  );
  @override
  late final GeneratedColumn<String> scryfallId = GeneratedColumn<String>(
    'scryfall_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _proxyQuantityMeta = const VerificationMeta(
    'proxyQuantity',
  );
  @override
  late final GeneratedColumn<int> proxyQuantity = GeneratedColumn<int>(
    'proxy_quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isFoilMeta = const VerificationMeta('isFoil');
  @override
  late final GeneratedColumn<bool> isFoil = GeneratedColumn<bool>(
    'is_foil',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_foil" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    wishlistId,
    scryfallId,
    name,
    quantity,
    proxyQuantity,
    isFoil,
    tags,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wishlist_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbWishlistCard> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('wishlist_id')) {
      context.handle(
        _wishlistIdMeta,
        wishlistId.isAcceptableOrUnknown(data['wishlist_id']!, _wishlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wishlistIdMeta);
    }
    if (data.containsKey('scryfall_id')) {
      context.handle(
        _scryfallIdMeta,
        scryfallId.isAcceptableOrUnknown(data['scryfall_id']!, _scryfallIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scryfallIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('proxy_quantity')) {
      context.handle(
        _proxyQuantityMeta,
        proxyQuantity.isAcceptableOrUnknown(
          data['proxy_quantity']!,
          _proxyQuantityMeta,
        ),
      );
    }
    if (data.containsKey('is_foil')) {
      context.handle(
        _isFoilMeta,
        isFoil.isAcceptableOrUnknown(data['is_foil']!, _isFoilMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbWishlistCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbWishlistCard(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      wishlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wishlist_id'],
      )!,
      scryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scryfall_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      proxyQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}proxy_quantity'],
      )!,
      isFoil: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_foil'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
    );
  }

  @override
  $WishlistCardsTable createAlias(String alias) {
    return $WishlistCardsTable(attachedDatabase, alias);
  }
}

class DbWishlistCard extends DataClass implements Insertable<DbWishlistCard> {
  final int id;
  final String wishlistId;
  final String scryfallId;
  final String name;
  final int quantity;
  final int proxyQuantity;
  final bool isFoil;
  final String tags;
  const DbWishlistCard({
    required this.id,
    required this.wishlistId,
    required this.scryfallId,
    required this.name,
    required this.quantity,
    required this.proxyQuantity,
    required this.isFoil,
    required this.tags,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['wishlist_id'] = Variable<String>(wishlistId);
    map['scryfall_id'] = Variable<String>(scryfallId);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<int>(quantity);
    map['proxy_quantity'] = Variable<int>(proxyQuantity);
    map['is_foil'] = Variable<bool>(isFoil);
    map['tags'] = Variable<String>(tags);
    return map;
  }

  WishlistCardsCompanion toCompanion(bool nullToAbsent) {
    return WishlistCardsCompanion(
      id: Value(id),
      wishlistId: Value(wishlistId),
      scryfallId: Value(scryfallId),
      name: Value(name),
      quantity: Value(quantity),
      proxyQuantity: Value(proxyQuantity),
      isFoil: Value(isFoil),
      tags: Value(tags),
    );
  }

  factory DbWishlistCard.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbWishlistCard(
      id: serializer.fromJson<int>(json['id']),
      wishlistId: serializer.fromJson<String>(json['wishlistId']),
      scryfallId: serializer.fromJson<String>(json['scryfallId']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<int>(json['quantity']),
      proxyQuantity: serializer.fromJson<int>(json['proxyQuantity']),
      isFoil: serializer.fromJson<bool>(json['isFoil']),
      tags: serializer.fromJson<String>(json['tags']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'wishlistId': serializer.toJson<String>(wishlistId),
      'scryfallId': serializer.toJson<String>(scryfallId),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<int>(quantity),
      'proxyQuantity': serializer.toJson<int>(proxyQuantity),
      'isFoil': serializer.toJson<bool>(isFoil),
      'tags': serializer.toJson<String>(tags),
    };
  }

  DbWishlistCard copyWith({
    int? id,
    String? wishlistId,
    String? scryfallId,
    String? name,
    int? quantity,
    int? proxyQuantity,
    bool? isFoil,
    String? tags,
  }) => DbWishlistCard(
    id: id ?? this.id,
    wishlistId: wishlistId ?? this.wishlistId,
    scryfallId: scryfallId ?? this.scryfallId,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    proxyQuantity: proxyQuantity ?? this.proxyQuantity,
    isFoil: isFoil ?? this.isFoil,
    tags: tags ?? this.tags,
  );
  DbWishlistCard copyWithCompanion(WishlistCardsCompanion data) {
    return DbWishlistCard(
      id: data.id.present ? data.id.value : this.id,
      wishlistId: data.wishlistId.present
          ? data.wishlistId.value
          : this.wishlistId,
      scryfallId: data.scryfallId.present
          ? data.scryfallId.value
          : this.scryfallId,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      proxyQuantity: data.proxyQuantity.present
          ? data.proxyQuantity.value
          : this.proxyQuantity,
      isFoil: data.isFoil.present ? data.isFoil.value : this.isFoil,
      tags: data.tags.present ? data.tags.value : this.tags,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbWishlistCard(')
          ..write('id: $id, ')
          ..write('wishlistId: $wishlistId, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('proxyQuantity: $proxyQuantity, ')
          ..write('isFoil: $isFoil, ')
          ..write('tags: $tags')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    wishlistId,
    scryfallId,
    name,
    quantity,
    proxyQuantity,
    isFoil,
    tags,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbWishlistCard &&
          other.id == this.id &&
          other.wishlistId == this.wishlistId &&
          other.scryfallId == this.scryfallId &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.proxyQuantity == this.proxyQuantity &&
          other.isFoil == this.isFoil &&
          other.tags == this.tags);
}

class WishlistCardsCompanion extends UpdateCompanion<DbWishlistCard> {
  final Value<int> id;
  final Value<String> wishlistId;
  final Value<String> scryfallId;
  final Value<String> name;
  final Value<int> quantity;
  final Value<int> proxyQuantity;
  final Value<bool> isFoil;
  final Value<String> tags;
  const WishlistCardsCompanion({
    this.id = const Value.absent(),
    this.wishlistId = const Value.absent(),
    this.scryfallId = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.proxyQuantity = const Value.absent(),
    this.isFoil = const Value.absent(),
    this.tags = const Value.absent(),
  });
  WishlistCardsCompanion.insert({
    this.id = const Value.absent(),
    required String wishlistId,
    required String scryfallId,
    required String name,
    this.quantity = const Value.absent(),
    this.proxyQuantity = const Value.absent(),
    this.isFoil = const Value.absent(),
    this.tags = const Value.absent(),
  }) : wishlistId = Value(wishlistId),
       scryfallId = Value(scryfallId),
       name = Value(name);
  static Insertable<DbWishlistCard> custom({
    Expression<int>? id,
    Expression<String>? wishlistId,
    Expression<String>? scryfallId,
    Expression<String>? name,
    Expression<int>? quantity,
    Expression<int>? proxyQuantity,
    Expression<bool>? isFoil,
    Expression<String>? tags,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wishlistId != null) 'wishlist_id': wishlistId,
      if (scryfallId != null) 'scryfall_id': scryfallId,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (proxyQuantity != null) 'proxy_quantity': proxyQuantity,
      if (isFoil != null) 'is_foil': isFoil,
      if (tags != null) 'tags': tags,
    });
  }

  WishlistCardsCompanion copyWith({
    Value<int>? id,
    Value<String>? wishlistId,
    Value<String>? scryfallId,
    Value<String>? name,
    Value<int>? quantity,
    Value<int>? proxyQuantity,
    Value<bool>? isFoil,
    Value<String>? tags,
  }) {
    return WishlistCardsCompanion(
      id: id ?? this.id,
      wishlistId: wishlistId ?? this.wishlistId,
      scryfallId: scryfallId ?? this.scryfallId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      proxyQuantity: proxyQuantity ?? this.proxyQuantity,
      isFoil: isFoil ?? this.isFoil,
      tags: tags ?? this.tags,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (wishlistId.present) {
      map['wishlist_id'] = Variable<String>(wishlistId.value);
    }
    if (scryfallId.present) {
      map['scryfall_id'] = Variable<String>(scryfallId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (proxyQuantity.present) {
      map['proxy_quantity'] = Variable<int>(proxyQuantity.value);
    }
    if (isFoil.present) {
      map['is_foil'] = Variable<bool>(isFoil.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishlistCardsCompanion(')
          ..write('id: $id, ')
          ..write('wishlistId: $wishlistId, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('proxyQuantity: $proxyQuantity, ')
          ..write('isFoil: $isFoil, ')
          ..write('tags: $tags')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, DbProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF2196F3),
  );
  static const VerificationMeta _commanderScryfallIdMeta =
      const VerificationMeta('commanderScryfallId');
  @override
  late final GeneratedColumn<String> commanderScryfallId =
      GeneratedColumn<String>(
        'commander_scryfall_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _commanderNameMeta = const VerificationMeta(
    'commanderName',
  );
  @override
  late final GeneratedColumn<String> commanderName = GeneratedColumn<String>(
    'commander_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commanderArtCropUrlMeta =
      const VerificationMeta('commanderArtCropUrl');
  @override
  late final GeneratedColumn<String> commanderArtCropUrl =
      GeneratedColumn<String>(
        'commander_art_crop_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _secondaryCommanderScryfallIdMeta =
      const VerificationMeta('secondaryCommanderScryfallId');
  @override
  late final GeneratedColumn<String> secondaryCommanderScryfallId =
      GeneratedColumn<String>(
        'secondary_commander_scryfall_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _secondaryCommanderNameMeta =
      const VerificationMeta('secondaryCommanderName');
  @override
  late final GeneratedColumn<String> secondaryCommanderName =
      GeneratedColumn<String>(
        'secondary_commander_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _secondaryCommanderArtCropUrlMeta =
      const VerificationMeta('secondaryCommanderArtCropUrl');
  @override
  late final GeneratedColumn<String> secondaryCommanderArtCropUrl =
      GeneratedColumn<String>(
        'secondary_commander_art_crop_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _commanderGalleryJsonMeta =
      const VerificationMeta('commanderGalleryJson');
  @override
  late final GeneratedColumn<String> commanderGalleryJson =
      GeneratedColumn<String>(
        'commander_gallery_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorValue,
    commanderScryfallId,
    commanderName,
    commanderArtCropUrl,
    secondaryCommanderScryfallId,
    secondaryCommanderName,
    secondaryCommanderArtCropUrl,
    commanderGalleryJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('commander_scryfall_id')) {
      context.handle(
        _commanderScryfallIdMeta,
        commanderScryfallId.isAcceptableOrUnknown(
          data['commander_scryfall_id']!,
          _commanderScryfallIdMeta,
        ),
      );
    }
    if (data.containsKey('commander_name')) {
      context.handle(
        _commanderNameMeta,
        commanderName.isAcceptableOrUnknown(
          data['commander_name']!,
          _commanderNameMeta,
        ),
      );
    }
    if (data.containsKey('commander_art_crop_url')) {
      context.handle(
        _commanderArtCropUrlMeta,
        commanderArtCropUrl.isAcceptableOrUnknown(
          data['commander_art_crop_url']!,
          _commanderArtCropUrlMeta,
        ),
      );
    }
    if (data.containsKey('secondary_commander_scryfall_id')) {
      context.handle(
        _secondaryCommanderScryfallIdMeta,
        secondaryCommanderScryfallId.isAcceptableOrUnknown(
          data['secondary_commander_scryfall_id']!,
          _secondaryCommanderScryfallIdMeta,
        ),
      );
    }
    if (data.containsKey('secondary_commander_name')) {
      context.handle(
        _secondaryCommanderNameMeta,
        secondaryCommanderName.isAcceptableOrUnknown(
          data['secondary_commander_name']!,
          _secondaryCommanderNameMeta,
        ),
      );
    }
    if (data.containsKey('secondary_commander_art_crop_url')) {
      context.handle(
        _secondaryCommanderArtCropUrlMeta,
        secondaryCommanderArtCropUrl.isAcceptableOrUnknown(
          data['secondary_commander_art_crop_url']!,
          _secondaryCommanderArtCropUrlMeta,
        ),
      );
    }
    if (data.containsKey('commander_gallery_json')) {
      context.handle(
        _commanderGalleryJsonMeta,
        commanderGalleryJson.isAcceptableOrUnknown(
          data['commander_gallery_json']!,
          _commanderGalleryJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      commanderScryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_scryfall_id'],
      ),
      commanderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_name'],
      ),
      commanderArtCropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_art_crop_url'],
      ),
      secondaryCommanderScryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_commander_scryfall_id'],
      ),
      secondaryCommanderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_commander_name'],
      ),
      secondaryCommanderArtCropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secondary_commander_art_crop_url'],
      ),
      commanderGalleryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_gallery_json'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class DbProfile extends DataClass implements Insertable<DbProfile> {
  final String id;
  final String name;
  final int colorValue;
  final String? commanderScryfallId;
  final String? commanderName;
  final String? commanderArtCropUrl;
  final String? secondaryCommanderScryfallId;
  final String? secondaryCommanderName;
  final String? secondaryCommanderArtCropUrl;

  /// JSON array of CommanderEntry objects — gallery of saved commanders
  final String commanderGalleryJson;
  const DbProfile({
    required this.id,
    required this.name,
    required this.colorValue,
    this.commanderScryfallId,
    this.commanderName,
    this.commanderArtCropUrl,
    this.secondaryCommanderScryfallId,
    this.secondaryCommanderName,
    this.secondaryCommanderArtCropUrl,
    required this.commanderGalleryJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || commanderScryfallId != null) {
      map['commander_scryfall_id'] = Variable<String>(commanderScryfallId);
    }
    if (!nullToAbsent || commanderName != null) {
      map['commander_name'] = Variable<String>(commanderName);
    }
    if (!nullToAbsent || commanderArtCropUrl != null) {
      map['commander_art_crop_url'] = Variable<String>(commanderArtCropUrl);
    }
    if (!nullToAbsent || secondaryCommanderScryfallId != null) {
      map['secondary_commander_scryfall_id'] = Variable<String>(
        secondaryCommanderScryfallId,
      );
    }
    if (!nullToAbsent || secondaryCommanderName != null) {
      map['secondary_commander_name'] = Variable<String>(
        secondaryCommanderName,
      );
    }
    if (!nullToAbsent || secondaryCommanderArtCropUrl != null) {
      map['secondary_commander_art_crop_url'] = Variable<String>(
        secondaryCommanderArtCropUrl,
      );
    }
    map['commander_gallery_json'] = Variable<String>(commanderGalleryJson);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      colorValue: Value(colorValue),
      commanderScryfallId: commanderScryfallId == null && nullToAbsent
          ? const Value.absent()
          : Value(commanderScryfallId),
      commanderName: commanderName == null && nullToAbsent
          ? const Value.absent()
          : Value(commanderName),
      commanderArtCropUrl: commanderArtCropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(commanderArtCropUrl),
      secondaryCommanderScryfallId:
          secondaryCommanderScryfallId == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryCommanderScryfallId),
      secondaryCommanderName: secondaryCommanderName == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryCommanderName),
      secondaryCommanderArtCropUrl:
          secondaryCommanderArtCropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(secondaryCommanderArtCropUrl),
      commanderGalleryJson: Value(commanderGalleryJson),
    );
  }

  factory DbProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      commanderScryfallId: serializer.fromJson<String?>(
        json['commanderScryfallId'],
      ),
      commanderName: serializer.fromJson<String?>(json['commanderName']),
      commanderArtCropUrl: serializer.fromJson<String?>(
        json['commanderArtCropUrl'],
      ),
      secondaryCommanderScryfallId: serializer.fromJson<String?>(
        json['secondaryCommanderScryfallId'],
      ),
      secondaryCommanderName: serializer.fromJson<String?>(
        json['secondaryCommanderName'],
      ),
      secondaryCommanderArtCropUrl: serializer.fromJson<String?>(
        json['secondaryCommanderArtCropUrl'],
      ),
      commanderGalleryJson: serializer.fromJson<String>(
        json['commanderGalleryJson'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'commanderScryfallId': serializer.toJson<String?>(commanderScryfallId),
      'commanderName': serializer.toJson<String?>(commanderName),
      'commanderArtCropUrl': serializer.toJson<String?>(commanderArtCropUrl),
      'secondaryCommanderScryfallId': serializer.toJson<String?>(
        secondaryCommanderScryfallId,
      ),
      'secondaryCommanderName': serializer.toJson<String?>(
        secondaryCommanderName,
      ),
      'secondaryCommanderArtCropUrl': serializer.toJson<String?>(
        secondaryCommanderArtCropUrl,
      ),
      'commanderGalleryJson': serializer.toJson<String>(commanderGalleryJson),
    };
  }

  DbProfile copyWith({
    String? id,
    String? name,
    int? colorValue,
    Value<String?> commanderScryfallId = const Value.absent(),
    Value<String?> commanderName = const Value.absent(),
    Value<String?> commanderArtCropUrl = const Value.absent(),
    Value<String?> secondaryCommanderScryfallId = const Value.absent(),
    Value<String?> secondaryCommanderName = const Value.absent(),
    Value<String?> secondaryCommanderArtCropUrl = const Value.absent(),
    String? commanderGalleryJson,
  }) => DbProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    commanderScryfallId: commanderScryfallId.present
        ? commanderScryfallId.value
        : this.commanderScryfallId,
    commanderName: commanderName.present
        ? commanderName.value
        : this.commanderName,
    commanderArtCropUrl: commanderArtCropUrl.present
        ? commanderArtCropUrl.value
        : this.commanderArtCropUrl,
    secondaryCommanderScryfallId: secondaryCommanderScryfallId.present
        ? secondaryCommanderScryfallId.value
        : this.secondaryCommanderScryfallId,
    secondaryCommanderName: secondaryCommanderName.present
        ? secondaryCommanderName.value
        : this.secondaryCommanderName,
    secondaryCommanderArtCropUrl: secondaryCommanderArtCropUrl.present
        ? secondaryCommanderArtCropUrl.value
        : this.secondaryCommanderArtCropUrl,
    commanderGalleryJson: commanderGalleryJson ?? this.commanderGalleryJson,
  );
  DbProfile copyWithCompanion(ProfilesCompanion data) {
    return DbProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      commanderScryfallId: data.commanderScryfallId.present
          ? data.commanderScryfallId.value
          : this.commanderScryfallId,
      commanderName: data.commanderName.present
          ? data.commanderName.value
          : this.commanderName,
      commanderArtCropUrl: data.commanderArtCropUrl.present
          ? data.commanderArtCropUrl.value
          : this.commanderArtCropUrl,
      secondaryCommanderScryfallId: data.secondaryCommanderScryfallId.present
          ? data.secondaryCommanderScryfallId.value
          : this.secondaryCommanderScryfallId,
      secondaryCommanderName: data.secondaryCommanderName.present
          ? data.secondaryCommanderName.value
          : this.secondaryCommanderName,
      secondaryCommanderArtCropUrl: data.secondaryCommanderArtCropUrl.present
          ? data.secondaryCommanderArtCropUrl.value
          : this.secondaryCommanderArtCropUrl,
      commanderGalleryJson: data.commanderGalleryJson.present
          ? data.commanderGalleryJson.value
          : this.commanderGalleryJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('commanderScryfallId: $commanderScryfallId, ')
          ..write('commanderName: $commanderName, ')
          ..write('commanderArtCropUrl: $commanderArtCropUrl, ')
          ..write(
            'secondaryCommanderScryfallId: $secondaryCommanderScryfallId, ',
          )
          ..write('secondaryCommanderName: $secondaryCommanderName, ')
          ..write(
            'secondaryCommanderArtCropUrl: $secondaryCommanderArtCropUrl, ',
          )
          ..write('commanderGalleryJson: $commanderGalleryJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    colorValue,
    commanderScryfallId,
    commanderName,
    commanderArtCropUrl,
    secondaryCommanderScryfallId,
    secondaryCommanderName,
    secondaryCommanderArtCropUrl,
    commanderGalleryJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.commanderScryfallId == this.commanderScryfallId &&
          other.commanderName == this.commanderName &&
          other.commanderArtCropUrl == this.commanderArtCropUrl &&
          other.secondaryCommanderScryfallId ==
              this.secondaryCommanderScryfallId &&
          other.secondaryCommanderName == this.secondaryCommanderName &&
          other.secondaryCommanderArtCropUrl ==
              this.secondaryCommanderArtCropUrl &&
          other.commanderGalleryJson == this.commanderGalleryJson);
}

class ProfilesCompanion extends UpdateCompanion<DbProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorValue;
  final Value<String?> commanderScryfallId;
  final Value<String?> commanderName;
  final Value<String?> commanderArtCropUrl;
  final Value<String?> secondaryCommanderScryfallId;
  final Value<String?> secondaryCommanderName;
  final Value<String?> secondaryCommanderArtCropUrl;
  final Value<String> commanderGalleryJson;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.commanderScryfallId = const Value.absent(),
    this.commanderName = const Value.absent(),
    this.commanderArtCropUrl = const Value.absent(),
    this.secondaryCommanderScryfallId = const Value.absent(),
    this.secondaryCommanderName = const Value.absent(),
    this.secondaryCommanderArtCropUrl = const Value.absent(),
    this.commanderGalleryJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String name,
    this.colorValue = const Value.absent(),
    this.commanderScryfallId = const Value.absent(),
    this.commanderName = const Value.absent(),
    this.commanderArtCropUrl = const Value.absent(),
    this.secondaryCommanderScryfallId = const Value.absent(),
    this.secondaryCommanderName = const Value.absent(),
    this.secondaryCommanderArtCropUrl = const Value.absent(),
    this.commanderGalleryJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<DbProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<String>? commanderScryfallId,
    Expression<String>? commanderName,
    Expression<String>? commanderArtCropUrl,
    Expression<String>? secondaryCommanderScryfallId,
    Expression<String>? secondaryCommanderName,
    Expression<String>? secondaryCommanderArtCropUrl,
    Expression<String>? commanderGalleryJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (commanderScryfallId != null)
        'commander_scryfall_id': commanderScryfallId,
      if (commanderName != null) 'commander_name': commanderName,
      if (commanderArtCropUrl != null)
        'commander_art_crop_url': commanderArtCropUrl,
      if (secondaryCommanderScryfallId != null)
        'secondary_commander_scryfall_id': secondaryCommanderScryfallId,
      if (secondaryCommanderName != null)
        'secondary_commander_name': secondaryCommanderName,
      if (secondaryCommanderArtCropUrl != null)
        'secondary_commander_art_crop_url': secondaryCommanderArtCropUrl,
      if (commanderGalleryJson != null)
        'commander_gallery_json': commanderGalleryJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorValue,
    Value<String?>? commanderScryfallId,
    Value<String?>? commanderName,
    Value<String?>? commanderArtCropUrl,
    Value<String?>? secondaryCommanderScryfallId,
    Value<String?>? secondaryCommanderName,
    Value<String?>? secondaryCommanderArtCropUrl,
    Value<String>? commanderGalleryJson,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      commanderScryfallId: commanderScryfallId ?? this.commanderScryfallId,
      commanderName: commanderName ?? this.commanderName,
      commanderArtCropUrl: commanderArtCropUrl ?? this.commanderArtCropUrl,
      secondaryCommanderScryfallId:
          secondaryCommanderScryfallId ?? this.secondaryCommanderScryfallId,
      secondaryCommanderName:
          secondaryCommanderName ?? this.secondaryCommanderName,
      secondaryCommanderArtCropUrl:
          secondaryCommanderArtCropUrl ?? this.secondaryCommanderArtCropUrl,
      commanderGalleryJson: commanderGalleryJson ?? this.commanderGalleryJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (commanderScryfallId.present) {
      map['commander_scryfall_id'] = Variable<String>(
        commanderScryfallId.value,
      );
    }
    if (commanderName.present) {
      map['commander_name'] = Variable<String>(commanderName.value);
    }
    if (commanderArtCropUrl.present) {
      map['commander_art_crop_url'] = Variable<String>(
        commanderArtCropUrl.value,
      );
    }
    if (secondaryCommanderScryfallId.present) {
      map['secondary_commander_scryfall_id'] = Variable<String>(
        secondaryCommanderScryfallId.value,
      );
    }
    if (secondaryCommanderName.present) {
      map['secondary_commander_name'] = Variable<String>(
        secondaryCommanderName.value,
      );
    }
    if (secondaryCommanderArtCropUrl.present) {
      map['secondary_commander_art_crop_url'] = Variable<String>(
        secondaryCommanderArtCropUrl.value,
      );
    }
    if (commanderGalleryJson.present) {
      map['commander_gallery_json'] = Variable<String>(
        commanderGalleryJson.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('commanderScryfallId: $commanderScryfallId, ')
          ..write('commanderName: $commanderName, ')
          ..write('commanderArtCropUrl: $commanderArtCropUrl, ')
          ..write(
            'secondaryCommanderScryfallId: $secondaryCommanderScryfallId, ',
          )
          ..write('secondaryCommanderName: $secondaryCommanderName, ')
          ..write(
            'secondaryCommanderArtCropUrl: $secondaryCommanderArtCropUrl, ',
          )
          ..write('commanderGalleryJson: $commanderGalleryJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GameHistoryItemsTable extends GameHistoryItems
    with TableInfo<$GameHistoryItemsTable, DbGameHistoryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameHistoryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _winnerNameMeta = const VerificationMeta(
    'winnerName',
  );
  @override
  late final GeneratedColumn<String> winnerName = GeneratedColumn<String>(
    'winner_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Standard'),
  );
  static const VerificationMeta _winMethodMeta = const VerificationMeta(
    'winMethod',
  );
  @override
  late final GeneratedColumn<String> winMethod = GeneratedColumn<String>(
    'win_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _playerStatesMeta = const VerificationMeta(
    'playerStates',
  );
  @override
  late final GeneratedColumn<String> playerStates = GeneratedColumn<String>(
    'player_states',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _startingLifeMeta = const VerificationMeta(
    'startingLife',
  );
  @override
  late final GeneratedColumn<int> startingLife = GeneratedColumn<int>(
    'starting_life',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _playerCountMeta = const VerificationMeta(
    'playerCount',
  );
  @override
  late final GeneratedColumn<int> playerCount = GeneratedColumn<int>(
    'player_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _winnerDeckNameMeta = const VerificationMeta(
    'winnerDeckName',
  );
  @override
  late final GeneratedColumn<String> winnerDeckName = GeneratedColumn<String>(
    'winner_deck_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    durationSeconds,
    winnerName,
    format,
    winMethod,
    playerStates,
    startingLife,
    playerCount,
    tag,
    winnerDeckName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_history_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbGameHistoryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('winner_name')) {
      context.handle(
        _winnerNameMeta,
        winnerName.isAcceptableOrUnknown(data['winner_name']!, _winnerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_winnerNameMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('win_method')) {
      context.handle(
        _winMethodMeta,
        winMethod.isAcceptableOrUnknown(data['win_method']!, _winMethodMeta),
      );
    }
    if (data.containsKey('player_states')) {
      context.handle(
        _playerStatesMeta,
        playerStates.isAcceptableOrUnknown(
          data['player_states']!,
          _playerStatesMeta,
        ),
      );
    }
    if (data.containsKey('starting_life')) {
      context.handle(
        _startingLifeMeta,
        startingLife.isAcceptableOrUnknown(
          data['starting_life']!,
          _startingLifeMeta,
        ),
      );
    }
    if (data.containsKey('player_count')) {
      context.handle(
        _playerCountMeta,
        playerCount.isAcceptableOrUnknown(
          data['player_count']!,
          _playerCountMeta,
        ),
      );
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    }
    if (data.containsKey('winner_deck_name')) {
      context.handle(
        _winnerDeckNameMeta,
        winnerDeckName.isAcceptableOrUnknown(
          data['winner_deck_name']!,
          _winnerDeckNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbGameHistoryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbGameHistoryItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      winnerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}winner_name'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      winMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}win_method'],
      )!,
      playerStates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_states'],
      )!,
      startingLife: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}starting_life'],
      )!,
      playerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}player_count'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      ),
      winnerDeckName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}winner_deck_name'],
      ),
    );
  }

  @override
  $GameHistoryItemsTable createAlias(String alias) {
    return $GameHistoryItemsTable(attachedDatabase, alias);
  }
}

class DbGameHistoryItem extends DataClass
    implements Insertable<DbGameHistoryItem> {
  final String id;
  final DateTime date;
  final int durationSeconds;
  final String winnerName;
  final String format;
  final String winMethod;
  final String playerStates;
  final int startingLife;
  final int playerCount;
  final String? tag;
  final String? winnerDeckName;
  const DbGameHistoryItem({
    required this.id,
    required this.date,
    required this.durationSeconds,
    required this.winnerName,
    required this.format,
    required this.winMethod,
    required this.playerStates,
    required this.startingLife,
    required this.playerCount,
    this.tag,
    this.winnerDeckName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<DateTime>(date);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['winner_name'] = Variable<String>(winnerName);
    map['format'] = Variable<String>(format);
    map['win_method'] = Variable<String>(winMethod);
    map['player_states'] = Variable<String>(playerStates);
    map['starting_life'] = Variable<int>(startingLife);
    map['player_count'] = Variable<int>(playerCount);
    if (!nullToAbsent || tag != null) {
      map['tag'] = Variable<String>(tag);
    }
    if (!nullToAbsent || winnerDeckName != null) {
      map['winner_deck_name'] = Variable<String>(winnerDeckName);
    }
    return map;
  }

  GameHistoryItemsCompanion toCompanion(bool nullToAbsent) {
    return GameHistoryItemsCompanion(
      id: Value(id),
      date: Value(date),
      durationSeconds: Value(durationSeconds),
      winnerName: Value(winnerName),
      format: Value(format),
      winMethod: Value(winMethod),
      playerStates: Value(playerStates),
      startingLife: Value(startingLife),
      playerCount: Value(playerCount),
      tag: tag == null && nullToAbsent ? const Value.absent() : Value(tag),
      winnerDeckName: winnerDeckName == null && nullToAbsent
          ? const Value.absent()
          : Value(winnerDeckName),
    );
  }

  factory DbGameHistoryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbGameHistoryItem(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      winnerName: serializer.fromJson<String>(json['winnerName']),
      format: serializer.fromJson<String>(json['format']),
      winMethod: serializer.fromJson<String>(json['winMethod']),
      playerStates: serializer.fromJson<String>(json['playerStates']),
      startingLife: serializer.fromJson<int>(json['startingLife']),
      playerCount: serializer.fromJson<int>(json['playerCount']),
      tag: serializer.fromJson<String?>(json['tag']),
      winnerDeckName: serializer.fromJson<String?>(json['winnerDeckName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<DateTime>(date),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'winnerName': serializer.toJson<String>(winnerName),
      'format': serializer.toJson<String>(format),
      'winMethod': serializer.toJson<String>(winMethod),
      'playerStates': serializer.toJson<String>(playerStates),
      'startingLife': serializer.toJson<int>(startingLife),
      'playerCount': serializer.toJson<int>(playerCount),
      'tag': serializer.toJson<String?>(tag),
      'winnerDeckName': serializer.toJson<String?>(winnerDeckName),
    };
  }

  DbGameHistoryItem copyWith({
    String? id,
    DateTime? date,
    int? durationSeconds,
    String? winnerName,
    String? format,
    String? winMethod,
    String? playerStates,
    int? startingLife,
    int? playerCount,
    Value<String?> tag = const Value.absent(),
    Value<String?> winnerDeckName = const Value.absent(),
  }) => DbGameHistoryItem(
    id: id ?? this.id,
    date: date ?? this.date,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    winnerName: winnerName ?? this.winnerName,
    format: format ?? this.format,
    winMethod: winMethod ?? this.winMethod,
    playerStates: playerStates ?? this.playerStates,
    startingLife: startingLife ?? this.startingLife,
    playerCount: playerCount ?? this.playerCount,
    tag: tag.present ? tag.value : this.tag,
    winnerDeckName: winnerDeckName.present
        ? winnerDeckName.value
        : this.winnerDeckName,
  );
  DbGameHistoryItem copyWithCompanion(GameHistoryItemsCompanion data) {
    return DbGameHistoryItem(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      winnerName: data.winnerName.present
          ? data.winnerName.value
          : this.winnerName,
      format: data.format.present ? data.format.value : this.format,
      winMethod: data.winMethod.present ? data.winMethod.value : this.winMethod,
      playerStates: data.playerStates.present
          ? data.playerStates.value
          : this.playerStates,
      startingLife: data.startingLife.present
          ? data.startingLife.value
          : this.startingLife,
      playerCount: data.playerCount.present
          ? data.playerCount.value
          : this.playerCount,
      tag: data.tag.present ? data.tag.value : this.tag,
      winnerDeckName: data.winnerDeckName.present
          ? data.winnerDeckName.value
          : this.winnerDeckName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbGameHistoryItem(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('winnerName: $winnerName, ')
          ..write('format: $format, ')
          ..write('winMethod: $winMethod, ')
          ..write('playerStates: $playerStates, ')
          ..write('startingLife: $startingLife, ')
          ..write('playerCount: $playerCount, ')
          ..write('tag: $tag, ')
          ..write('winnerDeckName: $winnerDeckName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    durationSeconds,
    winnerName,
    format,
    winMethod,
    playerStates,
    startingLife,
    playerCount,
    tag,
    winnerDeckName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbGameHistoryItem &&
          other.id == this.id &&
          other.date == this.date &&
          other.durationSeconds == this.durationSeconds &&
          other.winnerName == this.winnerName &&
          other.format == this.format &&
          other.winMethod == this.winMethod &&
          other.playerStates == this.playerStates &&
          other.startingLife == this.startingLife &&
          other.playerCount == this.playerCount &&
          other.tag == this.tag &&
          other.winnerDeckName == this.winnerDeckName);
}

class GameHistoryItemsCompanion extends UpdateCompanion<DbGameHistoryItem> {
  final Value<String> id;
  final Value<DateTime> date;
  final Value<int> durationSeconds;
  final Value<String> winnerName;
  final Value<String> format;
  final Value<String> winMethod;
  final Value<String> playerStates;
  final Value<int> startingLife;
  final Value<int> playerCount;
  final Value<String?> tag;
  final Value<String?> winnerDeckName;
  final Value<int> rowid;
  const GameHistoryItemsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.winnerName = const Value.absent(),
    this.format = const Value.absent(),
    this.winMethod = const Value.absent(),
    this.playerStates = const Value.absent(),
    this.startingLife = const Value.absent(),
    this.playerCount = const Value.absent(),
    this.tag = const Value.absent(),
    this.winnerDeckName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GameHistoryItemsCompanion.insert({
    required String id,
    required DateTime date,
    this.durationSeconds = const Value.absent(),
    required String winnerName,
    this.format = const Value.absent(),
    this.winMethod = const Value.absent(),
    this.playerStates = const Value.absent(),
    this.startingLife = const Value.absent(),
    this.playerCount = const Value.absent(),
    this.tag = const Value.absent(),
    this.winnerDeckName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       date = Value(date),
       winnerName = Value(winnerName);
  static Insertable<DbGameHistoryItem> custom({
    Expression<String>? id,
    Expression<DateTime>? date,
    Expression<int>? durationSeconds,
    Expression<String>? winnerName,
    Expression<String>? format,
    Expression<String>? winMethod,
    Expression<String>? playerStates,
    Expression<int>? startingLife,
    Expression<int>? playerCount,
    Expression<String>? tag,
    Expression<String>? winnerDeckName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (winnerName != null) 'winner_name': winnerName,
      if (format != null) 'format': format,
      if (winMethod != null) 'win_method': winMethod,
      if (playerStates != null) 'player_states': playerStates,
      if (startingLife != null) 'starting_life': startingLife,
      if (playerCount != null) 'player_count': playerCount,
      if (tag != null) 'tag': tag,
      if (winnerDeckName != null) 'winner_deck_name': winnerDeckName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GameHistoryItemsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? date,
    Value<int>? durationSeconds,
    Value<String>? winnerName,
    Value<String>? format,
    Value<String>? winMethod,
    Value<String>? playerStates,
    Value<int>? startingLife,
    Value<int>? playerCount,
    Value<String?>? tag,
    Value<String?>? winnerDeckName,
    Value<int>? rowid,
  }) {
    return GameHistoryItemsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      winnerName: winnerName ?? this.winnerName,
      format: format ?? this.format,
      winMethod: winMethod ?? this.winMethod,
      playerStates: playerStates ?? this.playerStates,
      startingLife: startingLife ?? this.startingLife,
      playerCount: playerCount ?? this.playerCount,
      tag: tag ?? this.tag,
      winnerDeckName: winnerDeckName ?? this.winnerDeckName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (winnerName.present) {
      map['winner_name'] = Variable<String>(winnerName.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (winMethod.present) {
      map['win_method'] = Variable<String>(winMethod.value);
    }
    if (playerStates.present) {
      map['player_states'] = Variable<String>(playerStates.value);
    }
    if (startingLife.present) {
      map['starting_life'] = Variable<int>(startingLife.value);
    }
    if (playerCount.present) {
      map['player_count'] = Variable<int>(playerCount.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (winnerDeckName.present) {
      map['winner_deck_name'] = Variable<String>(winnerDeckName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameHistoryItemsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('winnerName: $winnerName, ')
          ..write('format: $format, ')
          ..write('winMethod: $winMethod, ')
          ..write('playerStates: $playerStates, ')
          ..write('startingLife: $startingLife, ')
          ..write('playerCount: $playerCount, ')
          ..write('tag: $tag, ')
          ..write('winnerDeckName: $winnerDeckName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanHistoryItemsTable extends ScanHistoryItems
    with TableInfo<$ScanHistoryItemsTable, DbScanHistoryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanHistoryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scryfallIdMeta = const VerificationMeta(
    'scryfallId',
  );
  @override
  late final GeneratedColumn<String> scryfallId = GeneratedColumn<String>(
    'scryfall_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardNameMeta = const VerificationMeta(
    'cardName',
  );
  @override
  late final GeneratedColumn<String> cardName = GeneratedColumn<String>(
    'card_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scryfallId,
    cardName,
    imagePath,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_history_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbScanHistoryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scryfall_id')) {
      context.handle(
        _scryfallIdMeta,
        scryfallId.isAcceptableOrUnknown(data['scryfall_id']!, _scryfallIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scryfallIdMeta);
    }
    if (data.containsKey('card_name')) {
      context.handle(
        _cardNameMeta,
        cardName.isAcceptableOrUnknown(data['card_name']!, _cardNameMeta),
      );
    } else if (isInserting) {
      context.missing(_cardNameMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbScanHistoryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbScanHistoryItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      scryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scryfall_id'],
      )!,
      cardName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_name'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $ScanHistoryItemsTable createAlias(String alias) {
    return $ScanHistoryItemsTable(attachedDatabase, alias);
  }
}

class DbScanHistoryItem extends DataClass
    implements Insertable<DbScanHistoryItem> {
  final int id;
  final String scryfallId;
  final String cardName;
  final String? imagePath;
  final DateTime timestamp;
  const DbScanHistoryItem({
    required this.id,
    required this.scryfallId,
    required this.cardName,
    this.imagePath,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scryfall_id'] = Variable<String>(scryfallId);
    map['card_name'] = Variable<String>(cardName);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  ScanHistoryItemsCompanion toCompanion(bool nullToAbsent) {
    return ScanHistoryItemsCompanion(
      id: Value(id),
      scryfallId: Value(scryfallId),
      cardName: Value(cardName),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      timestamp: Value(timestamp),
    );
  }

  factory DbScanHistoryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbScanHistoryItem(
      id: serializer.fromJson<int>(json['id']),
      scryfallId: serializer.fromJson<String>(json['scryfallId']),
      cardName: serializer.fromJson<String>(json['cardName']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scryfallId': serializer.toJson<String>(scryfallId),
      'cardName': serializer.toJson<String>(cardName),
      'imagePath': serializer.toJson<String?>(imagePath),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  DbScanHistoryItem copyWith({
    int? id,
    String? scryfallId,
    String? cardName,
    Value<String?> imagePath = const Value.absent(),
    DateTime? timestamp,
  }) => DbScanHistoryItem(
    id: id ?? this.id,
    scryfallId: scryfallId ?? this.scryfallId,
    cardName: cardName ?? this.cardName,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    timestamp: timestamp ?? this.timestamp,
  );
  DbScanHistoryItem copyWithCompanion(ScanHistoryItemsCompanion data) {
    return DbScanHistoryItem(
      id: data.id.present ? data.id.value : this.id,
      scryfallId: data.scryfallId.present
          ? data.scryfallId.value
          : this.scryfallId,
      cardName: data.cardName.present ? data.cardName.value : this.cardName,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbScanHistoryItem(')
          ..write('id: $id, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('cardName: $cardName, ')
          ..write('imagePath: $imagePath, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, scryfallId, cardName, imagePath, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbScanHistoryItem &&
          other.id == this.id &&
          other.scryfallId == this.scryfallId &&
          other.cardName == this.cardName &&
          other.imagePath == this.imagePath &&
          other.timestamp == this.timestamp);
}

class ScanHistoryItemsCompanion extends UpdateCompanion<DbScanHistoryItem> {
  final Value<int> id;
  final Value<String> scryfallId;
  final Value<String> cardName;
  final Value<String?> imagePath;
  final Value<DateTime> timestamp;
  const ScanHistoryItemsCompanion({
    this.id = const Value.absent(),
    this.scryfallId = const Value.absent(),
    this.cardName = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  ScanHistoryItemsCompanion.insert({
    this.id = const Value.absent(),
    required String scryfallId,
    required String cardName,
    this.imagePath = const Value.absent(),
    required DateTime timestamp,
  }) : scryfallId = Value(scryfallId),
       cardName = Value(cardName),
       timestamp = Value(timestamp);
  static Insertable<DbScanHistoryItem> custom({
    Expression<int>? id,
    Expression<String>? scryfallId,
    Expression<String>? cardName,
    Expression<String>? imagePath,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scryfallId != null) 'scryfall_id': scryfallId,
      if (cardName != null) 'card_name': cardName,
      if (imagePath != null) 'image_path': imagePath,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  ScanHistoryItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? scryfallId,
    Value<String>? cardName,
    Value<String?>? imagePath,
    Value<DateTime>? timestamp,
  }) {
    return ScanHistoryItemsCompanion(
      id: id ?? this.id,
      scryfallId: scryfallId ?? this.scryfallId,
      cardName: cardName ?? this.cardName,
      imagePath: imagePath ?? this.imagePath,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scryfallId.present) {
      map['scryfall_id'] = Variable<String>(scryfallId.value);
    }
    if (cardName.present) {
      map['card_name'] = Variable<String>(cardName.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanHistoryItemsCompanion(')
          ..write('id: $id, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('cardName: $cardName, ')
          ..write('imagePath: $imagePath, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $CollectionValueHistoryTable extends CollectionValueHistory
    with TableInfo<$CollectionValueHistoryTable, DbCollectionValueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionValueHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _totalValueMeta = const VerificationMeta(
    'totalValue',
  );
  @override
  late final GeneratedColumn<double> totalValue = GeneratedColumn<double>(
    'total_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dateKey, totalValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_value_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbCollectionValueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('total_value')) {
      context.handle(
        _totalValueMeta,
        totalValue.isAcceptableOrUnknown(data['total_value']!, _totalValueMeta),
      );
    } else if (isInserting) {
      context.missing(_totalValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbCollectionValueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbCollectionValueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      totalValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_value'],
      )!,
    );
  }

  @override
  $CollectionValueHistoryTable createAlias(String alias) {
    return $CollectionValueHistoryTable(attachedDatabase, alias);
  }
}

class DbCollectionValueEntry extends DataClass
    implements Insertable<DbCollectionValueEntry> {
  final int id;
  final String dateKey;
  final double totalValue;
  const DbCollectionValueEntry({
    required this.id,
    required this.dateKey,
    required this.totalValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_key'] = Variable<String>(dateKey);
    map['total_value'] = Variable<double>(totalValue);
    return map;
  }

  CollectionValueHistoryCompanion toCompanion(bool nullToAbsent) {
    return CollectionValueHistoryCompanion(
      id: Value(id),
      dateKey: Value(dateKey),
      totalValue: Value(totalValue),
    );
  }

  factory DbCollectionValueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbCollectionValueEntry(
      id: serializer.fromJson<int>(json['id']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      totalValue: serializer.fromJson<double>(json['totalValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateKey': serializer.toJson<String>(dateKey),
      'totalValue': serializer.toJson<double>(totalValue),
    };
  }

  DbCollectionValueEntry copyWith({
    int? id,
    String? dateKey,
    double? totalValue,
  }) => DbCollectionValueEntry(
    id: id ?? this.id,
    dateKey: dateKey ?? this.dateKey,
    totalValue: totalValue ?? this.totalValue,
  );
  DbCollectionValueEntry copyWithCompanion(
    CollectionValueHistoryCompanion data,
  ) {
    return DbCollectionValueEntry(
      id: data.id.present ? data.id.value : this.id,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      totalValue: data.totalValue.present
          ? data.totalValue.value
          : this.totalValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbCollectionValueEntry(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('totalValue: $totalValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dateKey, totalValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbCollectionValueEntry &&
          other.id == this.id &&
          other.dateKey == this.dateKey &&
          other.totalValue == this.totalValue);
}

class CollectionValueHistoryCompanion
    extends UpdateCompanion<DbCollectionValueEntry> {
  final Value<int> id;
  final Value<String> dateKey;
  final Value<double> totalValue;
  const CollectionValueHistoryCompanion({
    this.id = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.totalValue = const Value.absent(),
  });
  CollectionValueHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String dateKey,
    required double totalValue,
  }) : dateKey = Value(dateKey),
       totalValue = Value(totalValue);
  static Insertable<DbCollectionValueEntry> custom({
    Expression<int>? id,
    Expression<String>? dateKey,
    Expression<double>? totalValue,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateKey != null) 'date_key': dateKey,
      if (totalValue != null) 'total_value': totalValue,
    });
  }

  CollectionValueHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? dateKey,
    Value<double>? totalValue,
  }) {
    return CollectionValueHistoryCompanion(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      totalValue: totalValue ?? this.totalValue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (totalValue.present) {
      map['total_value'] = Variable<double>(totalValue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionValueHistoryCompanion(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('totalValue: $totalValue')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, DbAppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbAppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DbAppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbAppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class DbAppSetting extends DataClass implements Insertable<DbAppSetting> {
  final String key;
  final String value;
  const DbAppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory DbAppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbAppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  DbAppSetting copyWith({String? key, String? value}) =>
      DbAppSetting(key: key ?? this.key, value: value ?? this.value);
  DbAppSetting copyWithCompanion(AppSettingsCompanion data) {
    return DbAppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbAppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbAppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<DbAppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DbAppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GameFormatsTable extends GameFormats
    with TableInfo<$GameFormatsTable, DbGameFormat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameFormatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startingLifeMeta = const VerificationMeta(
    'startingLife',
  );
  @override
  late final GeneratedColumn<int> startingLife = GeneratedColumn<int>(
    'starting_life',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _minPlayersMeta = const VerificationMeta(
    'minPlayers',
  );
  @override
  late final GeneratedColumn<int> minPlayers = GeneratedColumn<int>(
    'min_players',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _maxPlayersMeta = const VerificationMeta(
    'maxPlayers',
  );
  @override
  late final GeneratedColumn<int> maxPlayers = GeneratedColumn<int>(
    'max_players',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8),
  );
  static const VerificationMeta _maxCommandersMeta = const VerificationMeta(
    'maxCommanders',
  );
  @override
  late final GeneratedColumn<int> maxCommanders = GeneratedColumn<int>(
    'max_commanders',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enabledCounterIdsMeta = const VerificationMeta(
    'enabledCounterIds',
  );
  @override
  late final GeneratedColumn<String> enabledCounterIds =
      GeneratedColumn<String>(
        'enabled_counter_ids',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    startingLife,
    minPlayers,
    maxPlayers,
    maxCommanders,
    enabledCounterIds,
    isBuiltIn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_formats';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbGameFormat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('starting_life')) {
      context.handle(
        _startingLifeMeta,
        startingLife.isAcceptableOrUnknown(
          data['starting_life']!,
          _startingLifeMeta,
        ),
      );
    }
    if (data.containsKey('min_players')) {
      context.handle(
        _minPlayersMeta,
        minPlayers.isAcceptableOrUnknown(data['min_players']!, _minPlayersMeta),
      );
    }
    if (data.containsKey('max_players')) {
      context.handle(
        _maxPlayersMeta,
        maxPlayers.isAcceptableOrUnknown(data['max_players']!, _maxPlayersMeta),
      );
    }
    if (data.containsKey('max_commanders')) {
      context.handle(
        _maxCommandersMeta,
        maxCommanders.isAcceptableOrUnknown(
          data['max_commanders']!,
          _maxCommandersMeta,
        ),
      );
    }
    if (data.containsKey('enabled_counter_ids')) {
      context.handle(
        _enabledCounterIdsMeta,
        enabledCounterIds.isAcceptableOrUnknown(
          data['enabled_counter_ids']!,
          _enabledCounterIdsMeta,
        ),
      );
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbGameFormat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbGameFormat(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startingLife: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}starting_life'],
      )!,
      minPlayers: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_players'],
      )!,
      maxPlayers: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_players'],
      )!,
      maxCommanders: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_commanders'],
      )!,
      enabledCounterIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enabled_counter_ids'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
    );
  }

  @override
  $GameFormatsTable createAlias(String alias) {
    return $GameFormatsTable(attachedDatabase, alias);
  }
}

class DbGameFormat extends DataClass implements Insertable<DbGameFormat> {
  final String id;
  final String name;
  final int startingLife;
  final int minPlayers;
  final int maxPlayers;
  final int maxCommanders;
  final String enabledCounterIds;
  final bool isBuiltIn;
  const DbGameFormat({
    required this.id,
    required this.name,
    required this.startingLife,
    required this.minPlayers,
    required this.maxPlayers,
    required this.maxCommanders,
    required this.enabledCounterIds,
    required this.isBuiltIn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['starting_life'] = Variable<int>(startingLife);
    map['min_players'] = Variable<int>(minPlayers);
    map['max_players'] = Variable<int>(maxPlayers);
    map['max_commanders'] = Variable<int>(maxCommanders);
    map['enabled_counter_ids'] = Variable<String>(enabledCounterIds);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    return map;
  }

  GameFormatsCompanion toCompanion(bool nullToAbsent) {
    return GameFormatsCompanion(
      id: Value(id),
      name: Value(name),
      startingLife: Value(startingLife),
      minPlayers: Value(minPlayers),
      maxPlayers: Value(maxPlayers),
      maxCommanders: Value(maxCommanders),
      enabledCounterIds: Value(enabledCounterIds),
      isBuiltIn: Value(isBuiltIn),
    );
  }

  factory DbGameFormat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbGameFormat(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      startingLife: serializer.fromJson<int>(json['startingLife']),
      minPlayers: serializer.fromJson<int>(json['minPlayers']),
      maxPlayers: serializer.fromJson<int>(json['maxPlayers']),
      maxCommanders: serializer.fromJson<int>(json['maxCommanders']),
      enabledCounterIds: serializer.fromJson<String>(json['enabledCounterIds']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'startingLife': serializer.toJson<int>(startingLife),
      'minPlayers': serializer.toJson<int>(minPlayers),
      'maxPlayers': serializer.toJson<int>(maxPlayers),
      'maxCommanders': serializer.toJson<int>(maxCommanders),
      'enabledCounterIds': serializer.toJson<String>(enabledCounterIds),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
    };
  }

  DbGameFormat copyWith({
    String? id,
    String? name,
    int? startingLife,
    int? minPlayers,
    int? maxPlayers,
    int? maxCommanders,
    String? enabledCounterIds,
    bool? isBuiltIn,
  }) => DbGameFormat(
    id: id ?? this.id,
    name: name ?? this.name,
    startingLife: startingLife ?? this.startingLife,
    minPlayers: minPlayers ?? this.minPlayers,
    maxPlayers: maxPlayers ?? this.maxPlayers,
    maxCommanders: maxCommanders ?? this.maxCommanders,
    enabledCounterIds: enabledCounterIds ?? this.enabledCounterIds,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
  );
  DbGameFormat copyWithCompanion(GameFormatsCompanion data) {
    return DbGameFormat(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      startingLife: data.startingLife.present
          ? data.startingLife.value
          : this.startingLife,
      minPlayers: data.minPlayers.present
          ? data.minPlayers.value
          : this.minPlayers,
      maxPlayers: data.maxPlayers.present
          ? data.maxPlayers.value
          : this.maxPlayers,
      maxCommanders: data.maxCommanders.present
          ? data.maxCommanders.value
          : this.maxCommanders,
      enabledCounterIds: data.enabledCounterIds.present
          ? data.enabledCounterIds.value
          : this.enabledCounterIds,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbGameFormat(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startingLife: $startingLife, ')
          ..write('minPlayers: $minPlayers, ')
          ..write('maxPlayers: $maxPlayers, ')
          ..write('maxCommanders: $maxCommanders, ')
          ..write('enabledCounterIds: $enabledCounterIds, ')
          ..write('isBuiltIn: $isBuiltIn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    startingLife,
    minPlayers,
    maxPlayers,
    maxCommanders,
    enabledCounterIds,
    isBuiltIn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbGameFormat &&
          other.id == this.id &&
          other.name == this.name &&
          other.startingLife == this.startingLife &&
          other.minPlayers == this.minPlayers &&
          other.maxPlayers == this.maxPlayers &&
          other.maxCommanders == this.maxCommanders &&
          other.enabledCounterIds == this.enabledCounterIds &&
          other.isBuiltIn == this.isBuiltIn);
}

class GameFormatsCompanion extends UpdateCompanion<DbGameFormat> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> startingLife;
  final Value<int> minPlayers;
  final Value<int> maxPlayers;
  final Value<int> maxCommanders;
  final Value<String> enabledCounterIds;
  final Value<bool> isBuiltIn;
  final Value<int> rowid;
  const GameFormatsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.startingLife = const Value.absent(),
    this.minPlayers = const Value.absent(),
    this.maxPlayers = const Value.absent(),
    this.maxCommanders = const Value.absent(),
    this.enabledCounterIds = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GameFormatsCompanion.insert({
    required String id,
    required String name,
    this.startingLife = const Value.absent(),
    this.minPlayers = const Value.absent(),
    this.maxPlayers = const Value.absent(),
    this.maxCommanders = const Value.absent(),
    this.enabledCounterIds = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<DbGameFormat> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? startingLife,
    Expression<int>? minPlayers,
    Expression<int>? maxPlayers,
    Expression<int>? maxCommanders,
    Expression<String>? enabledCounterIds,
    Expression<bool>? isBuiltIn,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (startingLife != null) 'starting_life': startingLife,
      if (minPlayers != null) 'min_players': minPlayers,
      if (maxPlayers != null) 'max_players': maxPlayers,
      if (maxCommanders != null) 'max_commanders': maxCommanders,
      if (enabledCounterIds != null) 'enabled_counter_ids': enabledCounterIds,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GameFormatsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? startingLife,
    Value<int>? minPlayers,
    Value<int>? maxPlayers,
    Value<int>? maxCommanders,
    Value<String>? enabledCounterIds,
    Value<bool>? isBuiltIn,
    Value<int>? rowid,
  }) {
    return GameFormatsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      startingLife: startingLife ?? this.startingLife,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      maxCommanders: maxCommanders ?? this.maxCommanders,
      enabledCounterIds: enabledCounterIds ?? this.enabledCounterIds,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startingLife.present) {
      map['starting_life'] = Variable<int>(startingLife.value);
    }
    if (minPlayers.present) {
      map['min_players'] = Variable<int>(minPlayers.value);
    }
    if (maxPlayers.present) {
      map['max_players'] = Variable<int>(maxPlayers.value);
    }
    if (maxCommanders.present) {
      map['max_commanders'] = Variable<int>(maxCommanders.value);
    }
    if (enabledCounterIds.present) {
      map['enabled_counter_ids'] = Variable<String>(enabledCounterIds.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameFormatsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startingLife: $startingLife, ')
          ..write('minPlayers: $minPlayers, ')
          ..write('maxPlayers: $maxPlayers, ')
          ..write('maxCommanders: $maxCommanders, ')
          ..write('enabledCounterIds: $enabledCounterIds, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CounterTypesTable extends CounterTypes
    with TableInfo<$CounterTypesTable, DbCounterType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CounterTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('🔢'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFFFFFFFF),
  );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _maxValueMeta = const VerificationMeta(
    'maxValue',
  );
  @override
  late final GeneratedColumn<int> maxValue = GeneratedColumn<int>(
    'max_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    emoji,
    color,
    isBuiltIn,
    maxValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'counter_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbCounterType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    if (data.containsKey('max_value')) {
      context.handle(
        _maxValueMeta,
        maxValue.isAcceptableOrUnknown(data['max_value']!, _maxValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbCounterType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbCounterType(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
      maxValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_value'],
      ),
    );
  }

  @override
  $CounterTypesTable createAlias(String alias) {
    return $CounterTypesTable(attachedDatabase, alias);
  }
}

class DbCounterType extends DataClass implements Insertable<DbCounterType> {
  final String id;
  final String name;
  final String emoji;
  final int color;
  final bool isBuiltIn;
  final int? maxValue;
  const DbCounterType({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.isBuiltIn,
    this.maxValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['emoji'] = Variable<String>(emoji);
    map['color'] = Variable<int>(color);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    if (!nullToAbsent || maxValue != null) {
      map['max_value'] = Variable<int>(maxValue);
    }
    return map;
  }

  CounterTypesCompanion toCompanion(bool nullToAbsent) {
    return CounterTypesCompanion(
      id: Value(id),
      name: Value(name),
      emoji: Value(emoji),
      color: Value(color),
      isBuiltIn: Value(isBuiltIn),
      maxValue: maxValue == null && nullToAbsent
          ? const Value.absent()
          : Value(maxValue),
    );
  }

  factory DbCounterType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbCounterType(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String>(json['emoji']),
      color: serializer.fromJson<int>(json['color']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
      maxValue: serializer.fromJson<int?>(json['maxValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String>(emoji),
      'color': serializer.toJson<int>(color),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
      'maxValue': serializer.toJson<int?>(maxValue),
    };
  }

  DbCounterType copyWith({
    String? id,
    String? name,
    String? emoji,
    int? color,
    bool? isBuiltIn,
    Value<int?> maxValue = const Value.absent(),
  }) => DbCounterType(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    color: color ?? this.color,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    maxValue: maxValue.present ? maxValue.value : this.maxValue,
  );
  DbCounterType copyWithCompanion(CounterTypesCompanion data) {
    return DbCounterType(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      color: data.color.present ? data.color.value : this.color,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
      maxValue: data.maxValue.present ? data.maxValue.value : this.maxValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbCounterType(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('color: $color, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('maxValue: $maxValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, emoji, color, isBuiltIn, maxValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbCounterType &&
          other.id == this.id &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.color == this.color &&
          other.isBuiltIn == this.isBuiltIn &&
          other.maxValue == this.maxValue);
}

class CounterTypesCompanion extends UpdateCompanion<DbCounterType> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> emoji;
  final Value<int> color;
  final Value<bool> isBuiltIn;
  final Value<int?> maxValue;
  final Value<int> rowid;
  const CounterTypesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.color = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.maxValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CounterTypesCompanion.insert({
    required String id,
    required String name,
    this.emoji = const Value.absent(),
    this.color = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.maxValue = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<DbCounterType> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<int>? color,
    Expression<bool>? isBuiltIn,
    Expression<int>? maxValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (color != null) 'color': color,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (maxValue != null) 'max_value': maxValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CounterTypesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? emoji,
    Value<int>? color,
    Value<bool>? isBuiltIn,
    Value<int?>? maxValue,
    Value<int>? rowid,
  }) {
    return CounterTypesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      maxValue: maxValue ?? this.maxValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (maxValue.present) {
      map['max_value'] = Variable<int>(maxValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CounterTypesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('color: $color, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('maxValue: $maxValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayerConfigsTable extends PlayerConfigs
    with TableInfo<$PlayerConfigsTable, DbPlayerConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayerConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('guest'),
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF2196F3),
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta(
    'avatarPath',
  );
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedDeckIdMeta = const VerificationMeta(
    'linkedDeckId',
  );
  @override
  late final GeneratedColumn<String> linkedDeckId = GeneratedColumn<String>(
    'linked_deck_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    colorValue,
    avatarPath,
    linkedDeckId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'player_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbPlayerConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('linked_deck_id')) {
      context.handle(
        _linkedDeckIdMeta,
        linkedDeckId.isAcceptableOrUnknown(
          data['linked_deck_id']!,
          _linkedDeckIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbPlayerConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbPlayerConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      linkedDeckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_deck_id'],
      ),
    );
  }

  @override
  $PlayerConfigsTable createAlias(String alias) {
    return $PlayerConfigsTable(attachedDatabase, alias);
  }
}

class DbPlayerConfig extends DataClass implements Insertable<DbPlayerConfig> {
  final String id;
  final String name;
  final String type;
  final int colorValue;
  final String? avatarPath;
  final String? linkedDeckId;
  const DbPlayerConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.colorValue,
    this.avatarPath,
    this.linkedDeckId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    if (!nullToAbsent || linkedDeckId != null) {
      map['linked_deck_id'] = Variable<String>(linkedDeckId);
    }
    return map;
  }

  PlayerConfigsCompanion toCompanion(bool nullToAbsent) {
    return PlayerConfigsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      colorValue: Value(colorValue),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      linkedDeckId: linkedDeckId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedDeckId),
    );
  }

  factory DbPlayerConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbPlayerConfig(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      linkedDeckId: serializer.fromJson<String?>(json['linkedDeckId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'colorValue': serializer.toJson<int>(colorValue),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'linkedDeckId': serializer.toJson<String?>(linkedDeckId),
    };
  }

  DbPlayerConfig copyWith({
    String? id,
    String? name,
    String? type,
    int? colorValue,
    Value<String?> avatarPath = const Value.absent(),
    Value<String?> linkedDeckId = const Value.absent(),
  }) => DbPlayerConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    colorValue: colorValue ?? this.colorValue,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    linkedDeckId: linkedDeckId.present ? linkedDeckId.value : this.linkedDeckId,
  );
  DbPlayerConfig copyWithCompanion(PlayerConfigsCompanion data) {
    return DbPlayerConfig(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      linkedDeckId: data.linkedDeckId.present
          ? data.linkedDeckId.value
          : this.linkedDeckId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbPlayerConfig(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('colorValue: $colorValue, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('linkedDeckId: $linkedDeckId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, colorValue, avatarPath, linkedDeckId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbPlayerConfig &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.colorValue == this.colorValue &&
          other.avatarPath == this.avatarPath &&
          other.linkedDeckId == this.linkedDeckId);
}

class PlayerConfigsCompanion extends UpdateCompanion<DbPlayerConfig> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<int> colorValue;
  final Value<String?> avatarPath;
  final Value<String?> linkedDeckId;
  final Value<int> rowid;
  const PlayerConfigsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.linkedDeckId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayerConfigsCompanion.insert({
    required String id,
    required String name,
    this.type = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.linkedDeckId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<DbPlayerConfig> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? colorValue,
    Expression<String>? avatarPath,
    Expression<String>? linkedDeckId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (colorValue != null) 'color_value': colorValue,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (linkedDeckId != null) 'linked_deck_id': linkedDeckId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayerConfigsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<int>? colorValue,
    Value<String?>? avatarPath,
    Value<String?>? linkedDeckId,
    Value<int>? rowid,
  }) {
    return PlayerConfigsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorValue: colorValue ?? this.colorValue,
      avatarPath: avatarPath ?? this.avatarPath,
      linkedDeckId: linkedDeckId ?? this.linkedDeckId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (linkedDeckId.present) {
      map['linked_deck_id'] = Variable<String>(linkedDeckId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayerConfigsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('colorValue: $colorValue, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('linkedDeckId: $linkedDeckId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayerConfigCommandersTable extends PlayerConfigCommanders
    with TableInfo<$PlayerConfigCommandersTable, DbPlayerConfigCommander> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayerConfigCommandersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerConfigIdMeta = const VerificationMeta(
    'playerConfigId',
  );
  @override
  late final GeneratedColumn<String> playerConfigId = GeneratedColumn<String>(
    'player_config_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES player_configs (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scryfallIdMeta = const VerificationMeta(
    'scryfallId',
  );
  @override
  late final GeneratedColumn<String> scryfallId = GeneratedColumn<String>(
    'scryfall_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artCropUrlMeta = const VerificationMeta(
    'artCropUrl',
  );
  @override
  late final GeneratedColumn<String> artCropUrl = GeneratedColumn<String>(
    'art_crop_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playerConfigId,
    name,
    scryfallId,
    artCropUrl,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'player_config_commanders';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbPlayerConfigCommander> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('player_config_id')) {
      context.handle(
        _playerConfigIdMeta,
        playerConfigId.isAcceptableOrUnknown(
          data['player_config_id']!,
          _playerConfigIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playerConfigIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('scryfall_id')) {
      context.handle(
        _scryfallIdMeta,
        scryfallId.isAcceptableOrUnknown(data['scryfall_id']!, _scryfallIdMeta),
      );
    }
    if (data.containsKey('art_crop_url')) {
      context.handle(
        _artCropUrlMeta,
        artCropUrl.isAcceptableOrUnknown(
          data['art_crop_url']!,
          _artCropUrlMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbPlayerConfigCommander map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbPlayerConfigCommander(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      playerConfigId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_config_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      scryfallId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scryfall_id'],
      ),
      artCropUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}art_crop_url'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $PlayerConfigCommandersTable createAlias(String alias) {
    return $PlayerConfigCommandersTable(attachedDatabase, alias);
  }
}

class DbPlayerConfigCommander extends DataClass
    implements Insertable<DbPlayerConfigCommander> {
  final String id;
  final String playerConfigId;
  final String name;
  final String? scryfallId;
  final String? artCropUrl;
  final int sortOrder;
  const DbPlayerConfigCommander({
    required this.id,
    required this.playerConfigId,
    required this.name,
    this.scryfallId,
    this.artCropUrl,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['player_config_id'] = Variable<String>(playerConfigId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || scryfallId != null) {
      map['scryfall_id'] = Variable<String>(scryfallId);
    }
    if (!nullToAbsent || artCropUrl != null) {
      map['art_crop_url'] = Variable<String>(artCropUrl);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  PlayerConfigCommandersCompanion toCompanion(bool nullToAbsent) {
    return PlayerConfigCommandersCompanion(
      id: Value(id),
      playerConfigId: Value(playerConfigId),
      name: Value(name),
      scryfallId: scryfallId == null && nullToAbsent
          ? const Value.absent()
          : Value(scryfallId),
      artCropUrl: artCropUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(artCropUrl),
      sortOrder: Value(sortOrder),
    );
  }

  factory DbPlayerConfigCommander.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbPlayerConfigCommander(
      id: serializer.fromJson<String>(json['id']),
      playerConfigId: serializer.fromJson<String>(json['playerConfigId']),
      name: serializer.fromJson<String>(json['name']),
      scryfallId: serializer.fromJson<String?>(json['scryfallId']),
      artCropUrl: serializer.fromJson<String?>(json['artCropUrl']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'playerConfigId': serializer.toJson<String>(playerConfigId),
      'name': serializer.toJson<String>(name),
      'scryfallId': serializer.toJson<String?>(scryfallId),
      'artCropUrl': serializer.toJson<String?>(artCropUrl),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  DbPlayerConfigCommander copyWith({
    String? id,
    String? playerConfigId,
    String? name,
    Value<String?> scryfallId = const Value.absent(),
    Value<String?> artCropUrl = const Value.absent(),
    int? sortOrder,
  }) => DbPlayerConfigCommander(
    id: id ?? this.id,
    playerConfigId: playerConfigId ?? this.playerConfigId,
    name: name ?? this.name,
    scryfallId: scryfallId.present ? scryfallId.value : this.scryfallId,
    artCropUrl: artCropUrl.present ? artCropUrl.value : this.artCropUrl,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  DbPlayerConfigCommander copyWithCompanion(
    PlayerConfigCommandersCompanion data,
  ) {
    return DbPlayerConfigCommander(
      id: data.id.present ? data.id.value : this.id,
      playerConfigId: data.playerConfigId.present
          ? data.playerConfigId.value
          : this.playerConfigId,
      name: data.name.present ? data.name.value : this.name,
      scryfallId: data.scryfallId.present
          ? data.scryfallId.value
          : this.scryfallId,
      artCropUrl: data.artCropUrl.present
          ? data.artCropUrl.value
          : this.artCropUrl,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbPlayerConfigCommander(')
          ..write('id: $id, ')
          ..write('playerConfigId: $playerConfigId, ')
          ..write('name: $name, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('artCropUrl: $artCropUrl, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, playerConfigId, name, scryfallId, artCropUrl, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbPlayerConfigCommander &&
          other.id == this.id &&
          other.playerConfigId == this.playerConfigId &&
          other.name == this.name &&
          other.scryfallId == this.scryfallId &&
          other.artCropUrl == this.artCropUrl &&
          other.sortOrder == this.sortOrder);
}

class PlayerConfigCommandersCompanion
    extends UpdateCompanion<DbPlayerConfigCommander> {
  final Value<String> id;
  final Value<String> playerConfigId;
  final Value<String> name;
  final Value<String?> scryfallId;
  final Value<String?> artCropUrl;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const PlayerConfigCommandersCompanion({
    this.id = const Value.absent(),
    this.playerConfigId = const Value.absent(),
    this.name = const Value.absent(),
    this.scryfallId = const Value.absent(),
    this.artCropUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayerConfigCommandersCompanion.insert({
    required String id,
    required String playerConfigId,
    required String name,
    this.scryfallId = const Value.absent(),
    this.artCropUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       playerConfigId = Value(playerConfigId),
       name = Value(name);
  static Insertable<DbPlayerConfigCommander> custom({
    Expression<String>? id,
    Expression<String>? playerConfigId,
    Expression<String>? name,
    Expression<String>? scryfallId,
    Expression<String>? artCropUrl,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playerConfigId != null) 'player_config_id': playerConfigId,
      if (name != null) 'name': name,
      if (scryfallId != null) 'scryfall_id': scryfallId,
      if (artCropUrl != null) 'art_crop_url': artCropUrl,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayerConfigCommandersCompanion copyWith({
    Value<String>? id,
    Value<String>? playerConfigId,
    Value<String>? name,
    Value<String?>? scryfallId,
    Value<String?>? artCropUrl,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return PlayerConfigCommandersCompanion(
      id: id ?? this.id,
      playerConfigId: playerConfigId ?? this.playerConfigId,
      name: name ?? this.name,
      scryfallId: scryfallId ?? this.scryfallId,
      artCropUrl: artCropUrl ?? this.artCropUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (playerConfigId.present) {
      map['player_config_id'] = Variable<String>(playerConfigId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (scryfallId.present) {
      map['scryfall_id'] = Variable<String>(scryfallId.value);
    }
    if (artCropUrl.present) {
      map['art_crop_url'] = Variable<String>(artCropUrl.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayerConfigCommandersCompanion(')
          ..write('id: $id, ')
          ..write('playerConfigId: $playerConfigId, ')
          ..write('name: $name, ')
          ..write('scryfallId: $scryfallId, ')
          ..write('artCropUrl: $artCropUrl, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CollectionCardsTable collectionCards = $CollectionCardsTable(
    this,
  );
  late final $DecksTable decks = $DecksTable(this);
  late final $DeckCardsTable deckCards = $DeckCardsTable(this);
  late final $WishlistsTable wishlists = $WishlistsTable(this);
  late final $WishlistCardsTable wishlistCards = $WishlistCardsTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $GameHistoryItemsTable gameHistoryItems = $GameHistoryItemsTable(
    this,
  );
  late final $ScanHistoryItemsTable scanHistoryItems = $ScanHistoryItemsTable(
    this,
  );
  late final $CollectionValueHistoryTable collectionValueHistory =
      $CollectionValueHistoryTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $GameFormatsTable gameFormats = $GameFormatsTable(this);
  late final $CounterTypesTable counterTypes = $CounterTypesTable(this);
  late final $PlayerConfigsTable playerConfigs = $PlayerConfigsTable(this);
  late final $PlayerConfigCommandersTable playerConfigCommanders =
      $PlayerConfigCommandersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    collectionCards,
    decks,
    deckCards,
    wishlists,
    wishlistCards,
    profiles,
    gameHistoryItems,
    scanHistoryItems,
    collectionValueHistory,
    appSettings,
    gameFormats,
    counterTypes,
    playerConfigs,
    playerConfigCommanders,
  ];
}

typedef $$CollectionCardsTableCreateCompanionBuilder =
    CollectionCardsCompanion Function({
      Value<int> id,
      required String scryfallId,
      required String name,
      Value<int> quantity,
      Value<int> proxyQuantity,
      Value<bool> isFoil,
      Value<String> tags,
    });
typedef $$CollectionCardsTableUpdateCompanionBuilder =
    CollectionCardsCompanion Function({
      Value<int> id,
      Value<String> scryfallId,
      Value<String> name,
      Value<int> quantity,
      Value<int> proxyQuantity,
      Value<bool> isFoil,
      Value<String> tags,
    });

class $$CollectionCardsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionCardsTable> {
  $$CollectionCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proxyQuantity => $composableBuilder(
    column: $table.proxyQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFoil => $composableBuilder(
    column: $table.isFoil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectionCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionCardsTable> {
  $$CollectionCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proxyQuantity => $composableBuilder(
    column: $table.proxyQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFoil => $composableBuilder(
    column: $table.isFoil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionCardsTable> {
  $$CollectionCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get proxyQuantity => $composableBuilder(
    column: $table.proxyQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFoil =>
      $composableBuilder(column: $table.isFoil, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);
}

class $$CollectionCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionCardsTable,
          DbCollectionCard,
          $$CollectionCardsTableFilterComposer,
          $$CollectionCardsTableOrderingComposer,
          $$CollectionCardsTableAnnotationComposer,
          $$CollectionCardsTableCreateCompanionBuilder,
          $$CollectionCardsTableUpdateCompanionBuilder,
          (
            DbCollectionCard,
            BaseReferences<
              _$AppDatabase,
              $CollectionCardsTable,
              DbCollectionCard
            >,
          ),
          DbCollectionCard,
          PrefetchHooks Function()
        > {
  $$CollectionCardsTableTableManager(
    _$AppDatabase db,
    $CollectionCardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> scryfallId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> proxyQuantity = const Value.absent(),
                Value<bool> isFoil = const Value.absent(),
                Value<String> tags = const Value.absent(),
              }) => CollectionCardsCompanion(
                id: id,
                scryfallId: scryfallId,
                name: name,
                quantity: quantity,
                proxyQuantity: proxyQuantity,
                isFoil: isFoil,
                tags: tags,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String scryfallId,
                required String name,
                Value<int> quantity = const Value.absent(),
                Value<int> proxyQuantity = const Value.absent(),
                Value<bool> isFoil = const Value.absent(),
                Value<String> tags = const Value.absent(),
              }) => CollectionCardsCompanion.insert(
                id: id,
                scryfallId: scryfallId,
                name: name,
                quantity: quantity,
                proxyQuantity: proxyQuantity,
                isFoil: isFoil,
                tags: tags,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectionCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionCardsTable,
      DbCollectionCard,
      $$CollectionCardsTableFilterComposer,
      $$CollectionCardsTableOrderingComposer,
      $$CollectionCardsTableAnnotationComposer,
      $$CollectionCardsTableCreateCompanionBuilder,
      $$CollectionCardsTableUpdateCompanionBuilder,
      (
        DbCollectionCard,
        BaseReferences<_$AppDatabase, $CollectionCardsTable, DbCollectionCard>,
      ),
      DbCollectionCard,
      PrefetchHooks Function()
    >;
typedef $$DecksTableCreateCompanionBuilder =
    DecksCompanion Function({
      required String id,
      required String name,
      Value<String> format,
      Value<String?> commanderScryfallId,
      Value<String?> commanderSecondaryScryfallId,
      Value<String> colors,
      Value<int> rowid,
    });
typedef $$DecksTableUpdateCompanionBuilder =
    DecksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> format,
      Value<String?> commanderScryfallId,
      Value<String?> commanderSecondaryScryfallId,
      Value<String> colors,
      Value<int> rowid,
    });

final class $$DecksTableReferences
    extends BaseReferences<_$AppDatabase, $DecksTable, DbDeck> {
  $$DecksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DeckCardsTable, List<DbDeckCard>>
  _deckCardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.deckCards,
    aliasName: $_aliasNameGenerator(db.decks.id, db.deckCards.deckId),
  );

  $$DeckCardsTableProcessedTableManager get deckCardsRefs {
    final manager = $$DeckCardsTableTableManager(
      $_db,
      $_db.deckCards,
    ).filter((f) => f.deckId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_deckCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DecksTableFilterComposer extends Composer<_$AppDatabase, $DecksTable> {
  $$DecksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderScryfallId => $composableBuilder(
    column: $table.commanderScryfallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderSecondaryScryfallId => $composableBuilder(
    column: $table.commanderSecondaryScryfallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colors => $composableBuilder(
    column: $table.colors,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> deckCardsRefs(
    Expression<bool> Function($$DeckCardsTableFilterComposer f) f,
  ) {
    final $$DeckCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckCards,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckCardsTableFilterComposer(
            $db: $db,
            $table: $db.deckCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DecksTableOrderingComposer
    extends Composer<_$AppDatabase, $DecksTable> {
  $$DecksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commanderScryfallId => $composableBuilder(
    column: $table.commanderScryfallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commanderSecondaryScryfallId =>
      $composableBuilder(
        column: $table.commanderSecondaryScryfallId,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get colors => $composableBuilder(
    column: $table.colors,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DecksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DecksTable> {
  $$DecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get commanderScryfallId => $composableBuilder(
    column: $table.commanderScryfallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commanderSecondaryScryfallId =>
      $composableBuilder(
        column: $table.commanderSecondaryScryfallId,
        builder: (column) => column,
      );

  GeneratedColumn<String> get colors =>
      $composableBuilder(column: $table.colors, builder: (column) => column);

  Expression<T> deckCardsRefs<T extends Object>(
    Expression<T> Function($$DeckCardsTableAnnotationComposer a) f,
  ) {
    final $$DeckCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.deckCards,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.deckCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DecksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DecksTable,
          DbDeck,
          $$DecksTableFilterComposer,
          $$DecksTableOrderingComposer,
          $$DecksTableAnnotationComposer,
          $$DecksTableCreateCompanionBuilder,
          $$DecksTableUpdateCompanionBuilder,
          (DbDeck, $$DecksTableReferences),
          DbDeck,
          PrefetchHooks Function({bool deckCardsRefs})
        > {
  $$DecksTableTableManager(_$AppDatabase db, $DecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String?> commanderScryfallId = const Value.absent(),
                Value<String?> commanderSecondaryScryfallId =
                    const Value.absent(),
                Value<String> colors = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion(
                id: id,
                name: name,
                format: format,
                commanderScryfallId: commanderScryfallId,
                commanderSecondaryScryfallId: commanderSecondaryScryfallId,
                colors: colors,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> format = const Value.absent(),
                Value<String?> commanderScryfallId = const Value.absent(),
                Value<String?> commanderSecondaryScryfallId =
                    const Value.absent(),
                Value<String> colors = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion.insert(
                id: id,
                name: name,
                format: format,
                commanderScryfallId: commanderScryfallId,
                commanderSecondaryScryfallId: commanderSecondaryScryfallId,
                colors: colors,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$DecksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({deckCardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (deckCardsRefs) db.deckCards],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (deckCardsRefs)
                    await $_getPrefetchedData<DbDeck, $DecksTable, DbDeckCard>(
                      currentTable: table,
                      referencedTable: $$DecksTableReferences
                          ._deckCardsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DecksTableReferences(db, table, p0).deckCardsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.deckId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DecksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DecksTable,
      DbDeck,
      $$DecksTableFilterComposer,
      $$DecksTableOrderingComposer,
      $$DecksTableAnnotationComposer,
      $$DecksTableCreateCompanionBuilder,
      $$DecksTableUpdateCompanionBuilder,
      (DbDeck, $$DecksTableReferences),
      DbDeck,
      PrefetchHooks Function({bool deckCardsRefs})
    >;
typedef $$DeckCardsTableCreateCompanionBuilder =
    DeckCardsCompanion Function({
      Value<int> id,
      required String deckId,
      required String board,
      required String scryfallId,
      required String name,
      Value<int> quantity,
      Value<int> proxyQuantity,
      Value<bool> isFoil,
      Value<String> tags,
    });
typedef $$DeckCardsTableUpdateCompanionBuilder =
    DeckCardsCompanion Function({
      Value<int> id,
      Value<String> deckId,
      Value<String> board,
      Value<String> scryfallId,
      Value<String> name,
      Value<int> quantity,
      Value<int> proxyQuantity,
      Value<bool> isFoil,
      Value<String> tags,
    });

final class $$DeckCardsTableReferences
    extends BaseReferences<_$AppDatabase, $DeckCardsTable, DbDeckCard> {
  $$DeckCardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DecksTable _deckIdTable(_$AppDatabase db) => db.decks.createAlias(
    $_aliasNameGenerator(db.deckCards.deckId, db.decks.id),
  );

  $$DecksTableProcessedTableManager get deckId {
    final $_column = $_itemColumn<String>('deck_id')!;

    final manager = $$DecksTableTableManager(
      $_db,
      $_db.decks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deckIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeckCardsTableFilterComposer
    extends Composer<_$AppDatabase, $DeckCardsTable> {
  $$DeckCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get board => $composableBuilder(
    column: $table.board,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proxyQuantity => $composableBuilder(
    column: $table.proxyQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFoil => $composableBuilder(
    column: $table.isFoil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  $$DecksTableFilterComposer get deckId {
    final $$DecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableFilterComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeckCardsTable> {
  $$DeckCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get board => $composableBuilder(
    column: $table.board,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proxyQuantity => $composableBuilder(
    column: $table.proxyQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFoil => $composableBuilder(
    column: $table.isFoil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  $$DecksTableOrderingComposer get deckId {
    final $$DecksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableOrderingComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeckCardsTable> {
  $$DeckCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get board =>
      $composableBuilder(column: $table.board, builder: (column) => column);

  GeneratedColumn<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get proxyQuantity => $composableBuilder(
    column: $table.proxyQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFoil =>
      $composableBuilder(column: $table.isFoil, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  $$DecksTableAnnotationComposer get deckId {
    final $$DecksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableAnnotationComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeckCardsTable,
          DbDeckCard,
          $$DeckCardsTableFilterComposer,
          $$DeckCardsTableOrderingComposer,
          $$DeckCardsTableAnnotationComposer,
          $$DeckCardsTableCreateCompanionBuilder,
          $$DeckCardsTableUpdateCompanionBuilder,
          (DbDeckCard, $$DeckCardsTableReferences),
          DbDeckCard,
          PrefetchHooks Function({bool deckId})
        > {
  $$DeckCardsTableTableManager(_$AppDatabase db, $DeckCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deckId = const Value.absent(),
                Value<String> board = const Value.absent(),
                Value<String> scryfallId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> proxyQuantity = const Value.absent(),
                Value<bool> isFoil = const Value.absent(),
                Value<String> tags = const Value.absent(),
              }) => DeckCardsCompanion(
                id: id,
                deckId: deckId,
                board: board,
                scryfallId: scryfallId,
                name: name,
                quantity: quantity,
                proxyQuantity: proxyQuantity,
                isFoil: isFoil,
                tags: tags,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deckId,
                required String board,
                required String scryfallId,
                required String name,
                Value<int> quantity = const Value.absent(),
                Value<int> proxyQuantity = const Value.absent(),
                Value<bool> isFoil = const Value.absent(),
                Value<String> tags = const Value.absent(),
              }) => DeckCardsCompanion.insert(
                id: id,
                deckId: deckId,
                board: board,
                scryfallId: scryfallId,
                name: name,
                quantity: quantity,
                proxyQuantity: proxyQuantity,
                isFoil: isFoil,
                tags: tags,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DeckCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deckId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (deckId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deckId,
                                referencedTable: $$DeckCardsTableReferences
                                    ._deckIdTable(db),
                                referencedColumn: $$DeckCardsTableReferences
                                    ._deckIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DeckCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeckCardsTable,
      DbDeckCard,
      $$DeckCardsTableFilterComposer,
      $$DeckCardsTableOrderingComposer,
      $$DeckCardsTableAnnotationComposer,
      $$DeckCardsTableCreateCompanionBuilder,
      $$DeckCardsTableUpdateCompanionBuilder,
      (DbDeckCard, $$DeckCardsTableReferences),
      DbDeckCard,
      PrefetchHooks Function({bool deckId})
    >;
typedef $$WishlistsTableCreateCompanionBuilder =
    WishlistsCompanion Function({
      required String id,
      required String name,
      required DateTime dateCreated,
      Value<String?> iconScryfallId,
      Value<int> rowid,
    });
typedef $$WishlistsTableUpdateCompanionBuilder =
    WishlistsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> dateCreated,
      Value<String?> iconScryfallId,
      Value<int> rowid,
    });

final class $$WishlistsTableReferences
    extends BaseReferences<_$AppDatabase, $WishlistsTable, DbWishlist> {
  $$WishlistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WishlistCardsTable, List<DbWishlistCard>>
  _wishlistCardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wishlistCards,
    aliasName: $_aliasNameGenerator(
      db.wishlists.id,
      db.wishlistCards.wishlistId,
    ),
  );

  $$WishlistCardsTableProcessedTableManager get wishlistCardsRefs {
    final manager = $$WishlistCardsTableTableManager(
      $_db,
      $_db.wishlistCards,
    ).filter((f) => f.wishlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_wishlistCardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WishlistsTableFilterComposer
    extends Composer<_$AppDatabase, $WishlistsTable> {
  $$WishlistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateCreated => $composableBuilder(
    column: $table.dateCreated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconScryfallId => $composableBuilder(
    column: $table.iconScryfallId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> wishlistCardsRefs(
    Expression<bool> Function($$WishlistCardsTableFilterComposer f) f,
  ) {
    final $$WishlistCardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wishlistCards,
      getReferencedColumn: (t) => t.wishlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WishlistCardsTableFilterComposer(
            $db: $db,
            $table: $db.wishlistCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WishlistsTableOrderingComposer
    extends Composer<_$AppDatabase, $WishlistsTable> {
  $$WishlistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateCreated => $composableBuilder(
    column: $table.dateCreated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconScryfallId => $composableBuilder(
    column: $table.iconScryfallId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WishlistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WishlistsTable> {
  $$WishlistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get dateCreated => $composableBuilder(
    column: $table.dateCreated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconScryfallId => $composableBuilder(
    column: $table.iconScryfallId,
    builder: (column) => column,
  );

  Expression<T> wishlistCardsRefs<T extends Object>(
    Expression<T> Function($$WishlistCardsTableAnnotationComposer a) f,
  ) {
    final $$WishlistCardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wishlistCards,
      getReferencedColumn: (t) => t.wishlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WishlistCardsTableAnnotationComposer(
            $db: $db,
            $table: $db.wishlistCards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WishlistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WishlistsTable,
          DbWishlist,
          $$WishlistsTableFilterComposer,
          $$WishlistsTableOrderingComposer,
          $$WishlistsTableAnnotationComposer,
          $$WishlistsTableCreateCompanionBuilder,
          $$WishlistsTableUpdateCompanionBuilder,
          (DbWishlist, $$WishlistsTableReferences),
          DbWishlist,
          PrefetchHooks Function({bool wishlistCardsRefs})
        > {
  $$WishlistsTableTableManager(_$AppDatabase db, $WishlistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishlistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishlistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishlistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> dateCreated = const Value.absent(),
                Value<String?> iconScryfallId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WishlistsCompanion(
                id: id,
                name: name,
                dateCreated: dateCreated,
                iconScryfallId: iconScryfallId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime dateCreated,
                Value<String?> iconScryfallId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WishlistsCompanion.insert(
                id: id,
                name: name,
                dateCreated: dateCreated,
                iconScryfallId: iconScryfallId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WishlistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wishlistCardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (wishlistCardsRefs) db.wishlistCards,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (wishlistCardsRefs)
                    await $_getPrefetchedData<
                      DbWishlist,
                      $WishlistsTable,
                      DbWishlistCard
                    >(
                      currentTable: table,
                      referencedTable: $$WishlistsTableReferences
                          ._wishlistCardsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WishlistsTableReferences(
                            db,
                            table,
                            p0,
                          ).wishlistCardsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.wishlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WishlistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WishlistsTable,
      DbWishlist,
      $$WishlistsTableFilterComposer,
      $$WishlistsTableOrderingComposer,
      $$WishlistsTableAnnotationComposer,
      $$WishlistsTableCreateCompanionBuilder,
      $$WishlistsTableUpdateCompanionBuilder,
      (DbWishlist, $$WishlistsTableReferences),
      DbWishlist,
      PrefetchHooks Function({bool wishlistCardsRefs})
    >;
typedef $$WishlistCardsTableCreateCompanionBuilder =
    WishlistCardsCompanion Function({
      Value<int> id,
      required String wishlistId,
      required String scryfallId,
      required String name,
      Value<int> quantity,
      Value<int> proxyQuantity,
      Value<bool> isFoil,
      Value<String> tags,
    });
typedef $$WishlistCardsTableUpdateCompanionBuilder =
    WishlistCardsCompanion Function({
      Value<int> id,
      Value<String> wishlistId,
      Value<String> scryfallId,
      Value<String> name,
      Value<int> quantity,
      Value<int> proxyQuantity,
      Value<bool> isFoil,
      Value<String> tags,
    });

final class $$WishlistCardsTableReferences
    extends BaseReferences<_$AppDatabase, $WishlistCardsTable, DbWishlistCard> {
  $$WishlistCardsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WishlistsTable _wishlistIdTable(_$AppDatabase db) =>
      db.wishlists.createAlias(
        $_aliasNameGenerator(db.wishlistCards.wishlistId, db.wishlists.id),
      );

  $$WishlistsTableProcessedTableManager get wishlistId {
    final $_column = $_itemColumn<String>('wishlist_id')!;

    final manager = $$WishlistsTableTableManager(
      $_db,
      $_db.wishlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wishlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WishlistCardsTableFilterComposer
    extends Composer<_$AppDatabase, $WishlistCardsTable> {
  $$WishlistCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proxyQuantity => $composableBuilder(
    column: $table.proxyQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFoil => $composableBuilder(
    column: $table.isFoil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  $$WishlistsTableFilterComposer get wishlistId {
    final $$WishlistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wishlistId,
      referencedTable: $db.wishlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WishlistsTableFilterComposer(
            $db: $db,
            $table: $db.wishlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WishlistCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $WishlistCardsTable> {
  $$WishlistCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proxyQuantity => $composableBuilder(
    column: $table.proxyQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFoil => $composableBuilder(
    column: $table.isFoil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  $$WishlistsTableOrderingComposer get wishlistId {
    final $$WishlistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wishlistId,
      referencedTable: $db.wishlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WishlistsTableOrderingComposer(
            $db: $db,
            $table: $db.wishlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WishlistCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WishlistCardsTable> {
  $$WishlistCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get proxyQuantity => $composableBuilder(
    column: $table.proxyQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFoil =>
      $composableBuilder(column: $table.isFoil, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  $$WishlistsTableAnnotationComposer get wishlistId {
    final $$WishlistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wishlistId,
      referencedTable: $db.wishlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WishlistsTableAnnotationComposer(
            $db: $db,
            $table: $db.wishlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WishlistCardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WishlistCardsTable,
          DbWishlistCard,
          $$WishlistCardsTableFilterComposer,
          $$WishlistCardsTableOrderingComposer,
          $$WishlistCardsTableAnnotationComposer,
          $$WishlistCardsTableCreateCompanionBuilder,
          $$WishlistCardsTableUpdateCompanionBuilder,
          (DbWishlistCard, $$WishlistCardsTableReferences),
          DbWishlistCard,
          PrefetchHooks Function({bool wishlistId})
        > {
  $$WishlistCardsTableTableManager(_$AppDatabase db, $WishlistCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishlistCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishlistCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishlistCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> wishlistId = const Value.absent(),
                Value<String> scryfallId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> proxyQuantity = const Value.absent(),
                Value<bool> isFoil = const Value.absent(),
                Value<String> tags = const Value.absent(),
              }) => WishlistCardsCompanion(
                id: id,
                wishlistId: wishlistId,
                scryfallId: scryfallId,
                name: name,
                quantity: quantity,
                proxyQuantity: proxyQuantity,
                isFoil: isFoil,
                tags: tags,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String wishlistId,
                required String scryfallId,
                required String name,
                Value<int> quantity = const Value.absent(),
                Value<int> proxyQuantity = const Value.absent(),
                Value<bool> isFoil = const Value.absent(),
                Value<String> tags = const Value.absent(),
              }) => WishlistCardsCompanion.insert(
                id: id,
                wishlistId: wishlistId,
                scryfallId: scryfallId,
                name: name,
                quantity: quantity,
                proxyQuantity: proxyQuantity,
                isFoil: isFoil,
                tags: tags,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WishlistCardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({wishlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (wishlistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.wishlistId,
                                referencedTable: $$WishlistCardsTableReferences
                                    ._wishlistIdTable(db),
                                referencedColumn: $$WishlistCardsTableReferences
                                    ._wishlistIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WishlistCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WishlistCardsTable,
      DbWishlistCard,
      $$WishlistCardsTableFilterComposer,
      $$WishlistCardsTableOrderingComposer,
      $$WishlistCardsTableAnnotationComposer,
      $$WishlistCardsTableCreateCompanionBuilder,
      $$WishlistCardsTableUpdateCompanionBuilder,
      (DbWishlistCard, $$WishlistCardsTableReferences),
      DbWishlistCard,
      PrefetchHooks Function({bool wishlistId})
    >;
typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      required String id,
      required String name,
      Value<int> colorValue,
      Value<String?> commanderScryfallId,
      Value<String?> commanderName,
      Value<String?> commanderArtCropUrl,
      Value<String?> secondaryCommanderScryfallId,
      Value<String?> secondaryCommanderName,
      Value<String?> secondaryCommanderArtCropUrl,
      Value<String> commanderGalleryJson,
      Value<int> rowid,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> colorValue,
      Value<String?> commanderScryfallId,
      Value<String?> commanderName,
      Value<String?> commanderArtCropUrl,
      Value<String?> secondaryCommanderScryfallId,
      Value<String?> secondaryCommanderName,
      Value<String?> secondaryCommanderArtCropUrl,
      Value<String> commanderGalleryJson,
      Value<int> rowid,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderScryfallId => $composableBuilder(
    column: $table.commanderScryfallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderName => $composableBuilder(
    column: $table.commanderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderArtCropUrl => $composableBuilder(
    column: $table.commanderArtCropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryCommanderScryfallId => $composableBuilder(
    column: $table.secondaryCommanderScryfallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryCommanderName => $composableBuilder(
    column: $table.secondaryCommanderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secondaryCommanderArtCropUrl => $composableBuilder(
    column: $table.secondaryCommanderArtCropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderGalleryJson => $composableBuilder(
    column: $table.commanderGalleryJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commanderScryfallId => $composableBuilder(
    column: $table.commanderScryfallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commanderName => $composableBuilder(
    column: $table.commanderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commanderArtCropUrl => $composableBuilder(
    column: $table.commanderArtCropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryCommanderScryfallId =>
      $composableBuilder(
        column: $table.secondaryCommanderScryfallId,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get secondaryCommanderName => $composableBuilder(
    column: $table.secondaryCommanderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secondaryCommanderArtCropUrl =>
      $composableBuilder(
        column: $table.secondaryCommanderArtCropUrl,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get commanderGalleryJson => $composableBuilder(
    column: $table.commanderGalleryJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commanderScryfallId => $composableBuilder(
    column: $table.commanderScryfallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commanderName => $composableBuilder(
    column: $table.commanderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commanderArtCropUrl => $composableBuilder(
    column: $table.commanderArtCropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryCommanderScryfallId =>
      $composableBuilder(
        column: $table.secondaryCommanderScryfallId,
        builder: (column) => column,
      );

  GeneratedColumn<String> get secondaryCommanderName => $composableBuilder(
    column: $table.secondaryCommanderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get secondaryCommanderArtCropUrl =>
      $composableBuilder(
        column: $table.secondaryCommanderArtCropUrl,
        builder: (column) => column,
      );

  GeneratedColumn<String> get commanderGalleryJson => $composableBuilder(
    column: $table.commanderGalleryJson,
    builder: (column) => column,
  );
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          DbProfile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (DbProfile, BaseReferences<_$AppDatabase, $ProfilesTable, DbProfile>),
          DbProfile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String?> commanderScryfallId = const Value.absent(),
                Value<String?> commanderName = const Value.absent(),
                Value<String?> commanderArtCropUrl = const Value.absent(),
                Value<String?> secondaryCommanderScryfallId =
                    const Value.absent(),
                Value<String?> secondaryCommanderName = const Value.absent(),
                Value<String?> secondaryCommanderArtCropUrl =
                    const Value.absent(),
                Value<String> commanderGalleryJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                name: name,
                colorValue: colorValue,
                commanderScryfallId: commanderScryfallId,
                commanderName: commanderName,
                commanderArtCropUrl: commanderArtCropUrl,
                secondaryCommanderScryfallId: secondaryCommanderScryfallId,
                secondaryCommanderName: secondaryCommanderName,
                secondaryCommanderArtCropUrl: secondaryCommanderArtCropUrl,
                commanderGalleryJson: commanderGalleryJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> colorValue = const Value.absent(),
                Value<String?> commanderScryfallId = const Value.absent(),
                Value<String?> commanderName = const Value.absent(),
                Value<String?> commanderArtCropUrl = const Value.absent(),
                Value<String?> secondaryCommanderScryfallId =
                    const Value.absent(),
                Value<String?> secondaryCommanderName = const Value.absent(),
                Value<String?> secondaryCommanderArtCropUrl =
                    const Value.absent(),
                Value<String> commanderGalleryJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                name: name,
                colorValue: colorValue,
                commanderScryfallId: commanderScryfallId,
                commanderName: commanderName,
                commanderArtCropUrl: commanderArtCropUrl,
                secondaryCommanderScryfallId: secondaryCommanderScryfallId,
                secondaryCommanderName: secondaryCommanderName,
                secondaryCommanderArtCropUrl: secondaryCommanderArtCropUrl,
                commanderGalleryJson: commanderGalleryJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      DbProfile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (DbProfile, BaseReferences<_$AppDatabase, $ProfilesTable, DbProfile>),
      DbProfile,
      PrefetchHooks Function()
    >;
typedef $$GameHistoryItemsTableCreateCompanionBuilder =
    GameHistoryItemsCompanion Function({
      required String id,
      required DateTime date,
      Value<int> durationSeconds,
      required String winnerName,
      Value<String> format,
      Value<String> winMethod,
      Value<String> playerStates,
      Value<int> startingLife,
      Value<int> playerCount,
      Value<String?> tag,
      Value<String?> winnerDeckName,
      Value<int> rowid,
    });
typedef $$GameHistoryItemsTableUpdateCompanionBuilder =
    GameHistoryItemsCompanion Function({
      Value<String> id,
      Value<DateTime> date,
      Value<int> durationSeconds,
      Value<String> winnerName,
      Value<String> format,
      Value<String> winMethod,
      Value<String> playerStates,
      Value<int> startingLife,
      Value<int> playerCount,
      Value<String?> tag,
      Value<String?> winnerDeckName,
      Value<int> rowid,
    });

class $$GameHistoryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $GameHistoryItemsTable> {
  $$GameHistoryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get winnerName => $composableBuilder(
    column: $table.winnerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get winMethod => $composableBuilder(
    column: $table.winMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerStates => $composableBuilder(
    column: $table.playerStates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playerCount => $composableBuilder(
    column: $table.playerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get winnerDeckName => $composableBuilder(
    column: $table.winnerDeckName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameHistoryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $GameHistoryItemsTable> {
  $$GameHistoryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get winnerName => $composableBuilder(
    column: $table.winnerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get winMethod => $composableBuilder(
    column: $table.winMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerStates => $composableBuilder(
    column: $table.playerStates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playerCount => $composableBuilder(
    column: $table.playerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get winnerDeckName => $composableBuilder(
    column: $table.winnerDeckName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameHistoryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameHistoryItemsTable> {
  $$GameHistoryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get winnerName => $composableBuilder(
    column: $table.winnerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get winMethod =>
      $composableBuilder(column: $table.winMethod, builder: (column) => column);

  GeneratedColumn<String> get playerStates => $composableBuilder(
    column: $table.playerStates,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playerCount => $composableBuilder(
    column: $table.playerCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get winnerDeckName => $composableBuilder(
    column: $table.winnerDeckName,
    builder: (column) => column,
  );
}

class $$GameHistoryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameHistoryItemsTable,
          DbGameHistoryItem,
          $$GameHistoryItemsTableFilterComposer,
          $$GameHistoryItemsTableOrderingComposer,
          $$GameHistoryItemsTableAnnotationComposer,
          $$GameHistoryItemsTableCreateCompanionBuilder,
          $$GameHistoryItemsTableUpdateCompanionBuilder,
          (
            DbGameHistoryItem,
            BaseReferences<
              _$AppDatabase,
              $GameHistoryItemsTable,
              DbGameHistoryItem
            >,
          ),
          DbGameHistoryItem,
          PrefetchHooks Function()
        > {
  $$GameHistoryItemsTableTableManager(
    _$AppDatabase db,
    $GameHistoryItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameHistoryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameHistoryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameHistoryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<String> winnerName = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> winMethod = const Value.absent(),
                Value<String> playerStates = const Value.absent(),
                Value<int> startingLife = const Value.absent(),
                Value<int> playerCount = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<String?> winnerDeckName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameHistoryItemsCompanion(
                id: id,
                date: date,
                durationSeconds: durationSeconds,
                winnerName: winnerName,
                format: format,
                winMethod: winMethod,
                playerStates: playerStates,
                startingLife: startingLife,
                playerCount: playerCount,
                tag: tag,
                winnerDeckName: winnerDeckName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime date,
                Value<int> durationSeconds = const Value.absent(),
                required String winnerName,
                Value<String> format = const Value.absent(),
                Value<String> winMethod = const Value.absent(),
                Value<String> playerStates = const Value.absent(),
                Value<int> startingLife = const Value.absent(),
                Value<int> playerCount = const Value.absent(),
                Value<String?> tag = const Value.absent(),
                Value<String?> winnerDeckName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameHistoryItemsCompanion.insert(
                id: id,
                date: date,
                durationSeconds: durationSeconds,
                winnerName: winnerName,
                format: format,
                winMethod: winMethod,
                playerStates: playerStates,
                startingLife: startingLife,
                playerCount: playerCount,
                tag: tag,
                winnerDeckName: winnerDeckName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameHistoryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameHistoryItemsTable,
      DbGameHistoryItem,
      $$GameHistoryItemsTableFilterComposer,
      $$GameHistoryItemsTableOrderingComposer,
      $$GameHistoryItemsTableAnnotationComposer,
      $$GameHistoryItemsTableCreateCompanionBuilder,
      $$GameHistoryItemsTableUpdateCompanionBuilder,
      (
        DbGameHistoryItem,
        BaseReferences<
          _$AppDatabase,
          $GameHistoryItemsTable,
          DbGameHistoryItem
        >,
      ),
      DbGameHistoryItem,
      PrefetchHooks Function()
    >;
typedef $$ScanHistoryItemsTableCreateCompanionBuilder =
    ScanHistoryItemsCompanion Function({
      Value<int> id,
      required String scryfallId,
      required String cardName,
      Value<String?> imagePath,
      required DateTime timestamp,
    });
typedef $$ScanHistoryItemsTableUpdateCompanionBuilder =
    ScanHistoryItemsCompanion Function({
      Value<int> id,
      Value<String> scryfallId,
      Value<String> cardName,
      Value<String?> imagePath,
      Value<DateTime> timestamp,
    });

class $$ScanHistoryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ScanHistoryItemsTable> {
  $$ScanHistoryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardName => $composableBuilder(
    column: $table.cardName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanHistoryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanHistoryItemsTable> {
  $$ScanHistoryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardName => $composableBuilder(
    column: $table.cardName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanHistoryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanHistoryItemsTable> {
  $$ScanHistoryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardName =>
      $composableBuilder(column: $table.cardName, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$ScanHistoryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanHistoryItemsTable,
          DbScanHistoryItem,
          $$ScanHistoryItemsTableFilterComposer,
          $$ScanHistoryItemsTableOrderingComposer,
          $$ScanHistoryItemsTableAnnotationComposer,
          $$ScanHistoryItemsTableCreateCompanionBuilder,
          $$ScanHistoryItemsTableUpdateCompanionBuilder,
          (
            DbScanHistoryItem,
            BaseReferences<
              _$AppDatabase,
              $ScanHistoryItemsTable,
              DbScanHistoryItem
            >,
          ),
          DbScanHistoryItem,
          PrefetchHooks Function()
        > {
  $$ScanHistoryItemsTableTableManager(
    _$AppDatabase db,
    $ScanHistoryItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanHistoryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanHistoryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanHistoryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> scryfallId = const Value.absent(),
                Value<String> cardName = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => ScanHistoryItemsCompanion(
                id: id,
                scryfallId: scryfallId,
                cardName: cardName,
                imagePath: imagePath,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String scryfallId,
                required String cardName,
                Value<String?> imagePath = const Value.absent(),
                required DateTime timestamp,
              }) => ScanHistoryItemsCompanion.insert(
                id: id,
                scryfallId: scryfallId,
                cardName: cardName,
                imagePath: imagePath,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanHistoryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanHistoryItemsTable,
      DbScanHistoryItem,
      $$ScanHistoryItemsTableFilterComposer,
      $$ScanHistoryItemsTableOrderingComposer,
      $$ScanHistoryItemsTableAnnotationComposer,
      $$ScanHistoryItemsTableCreateCompanionBuilder,
      $$ScanHistoryItemsTableUpdateCompanionBuilder,
      (
        DbScanHistoryItem,
        BaseReferences<
          _$AppDatabase,
          $ScanHistoryItemsTable,
          DbScanHistoryItem
        >,
      ),
      DbScanHistoryItem,
      PrefetchHooks Function()
    >;
typedef $$CollectionValueHistoryTableCreateCompanionBuilder =
    CollectionValueHistoryCompanion Function({
      Value<int> id,
      required String dateKey,
      required double totalValue,
    });
typedef $$CollectionValueHistoryTableUpdateCompanionBuilder =
    CollectionValueHistoryCompanion Function({
      Value<int> id,
      Value<String> dateKey,
      Value<double> totalValue,
    });

class $$CollectionValueHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionValueHistoryTable> {
  $$CollectionValueHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalValue => $composableBuilder(
    column: $table.totalValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CollectionValueHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionValueHistoryTable> {
  $$CollectionValueHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalValue => $composableBuilder(
    column: $table.totalValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionValueHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionValueHistoryTable> {
  $$CollectionValueHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<double> get totalValue => $composableBuilder(
    column: $table.totalValue,
    builder: (column) => column,
  );
}

class $$CollectionValueHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionValueHistoryTable,
          DbCollectionValueEntry,
          $$CollectionValueHistoryTableFilterComposer,
          $$CollectionValueHistoryTableOrderingComposer,
          $$CollectionValueHistoryTableAnnotationComposer,
          $$CollectionValueHistoryTableCreateCompanionBuilder,
          $$CollectionValueHistoryTableUpdateCompanionBuilder,
          (
            DbCollectionValueEntry,
            BaseReferences<
              _$AppDatabase,
              $CollectionValueHistoryTable,
              DbCollectionValueEntry
            >,
          ),
          DbCollectionValueEntry,
          PrefetchHooks Function()
        > {
  $$CollectionValueHistoryTableTableManager(
    _$AppDatabase db,
    $CollectionValueHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionValueHistoryTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CollectionValueHistoryTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CollectionValueHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<double> totalValue = const Value.absent(),
              }) => CollectionValueHistoryCompanion(
                id: id,
                dateKey: dateKey,
                totalValue: totalValue,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String dateKey,
                required double totalValue,
              }) => CollectionValueHistoryCompanion.insert(
                id: id,
                dateKey: dateKey,
                totalValue: totalValue,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CollectionValueHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionValueHistoryTable,
      DbCollectionValueEntry,
      $$CollectionValueHistoryTableFilterComposer,
      $$CollectionValueHistoryTableOrderingComposer,
      $$CollectionValueHistoryTableAnnotationComposer,
      $$CollectionValueHistoryTableCreateCompanionBuilder,
      $$CollectionValueHistoryTableUpdateCompanionBuilder,
      (
        DbCollectionValueEntry,
        BaseReferences<
          _$AppDatabase,
          $CollectionValueHistoryTable,
          DbCollectionValueEntry
        >,
      ),
      DbCollectionValueEntry,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          DbAppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            DbAppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, DbAppSetting>,
          ),
          DbAppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      DbAppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        DbAppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, DbAppSetting>,
      ),
      DbAppSetting,
      PrefetchHooks Function()
    >;
typedef $$GameFormatsTableCreateCompanionBuilder =
    GameFormatsCompanion Function({
      required String id,
      required String name,
      Value<int> startingLife,
      Value<int> minPlayers,
      Value<int> maxPlayers,
      Value<int> maxCommanders,
      Value<String> enabledCounterIds,
      Value<bool> isBuiltIn,
      Value<int> rowid,
    });
typedef $$GameFormatsTableUpdateCompanionBuilder =
    GameFormatsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> startingLife,
      Value<int> minPlayers,
      Value<int> maxPlayers,
      Value<int> maxCommanders,
      Value<String> enabledCounterIds,
      Value<bool> isBuiltIn,
      Value<int> rowid,
    });

class $$GameFormatsTableFilterComposer
    extends Composer<_$AppDatabase, $GameFormatsTable> {
  $$GameFormatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minPlayers => $composableBuilder(
    column: $table.minPlayers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxPlayers => $composableBuilder(
    column: $table.maxPlayers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxCommanders => $composableBuilder(
    column: $table.maxCommanders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabledCounterIds => $composableBuilder(
    column: $table.enabledCounterIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameFormatsTableOrderingComposer
    extends Composer<_$AppDatabase, $GameFormatsTable> {
  $$GameFormatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minPlayers => $composableBuilder(
    column: $table.minPlayers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxPlayers => $composableBuilder(
    column: $table.maxPlayers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxCommanders => $composableBuilder(
    column: $table.maxCommanders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabledCounterIds => $composableBuilder(
    column: $table.enabledCounterIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameFormatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameFormatsTable> {
  $$GameFormatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => column,
  );

  GeneratedColumn<int> get minPlayers => $composableBuilder(
    column: $table.minPlayers,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxPlayers => $composableBuilder(
    column: $table.maxPlayers,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxCommanders => $composableBuilder(
    column: $table.maxCommanders,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enabledCounterIds => $composableBuilder(
    column: $table.enabledCounterIds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);
}

class $$GameFormatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameFormatsTable,
          DbGameFormat,
          $$GameFormatsTableFilterComposer,
          $$GameFormatsTableOrderingComposer,
          $$GameFormatsTableAnnotationComposer,
          $$GameFormatsTableCreateCompanionBuilder,
          $$GameFormatsTableUpdateCompanionBuilder,
          (
            DbGameFormat,
            BaseReferences<_$AppDatabase, $GameFormatsTable, DbGameFormat>,
          ),
          DbGameFormat,
          PrefetchHooks Function()
        > {
  $$GameFormatsTableTableManager(_$AppDatabase db, $GameFormatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameFormatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameFormatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameFormatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> startingLife = const Value.absent(),
                Value<int> minPlayers = const Value.absent(),
                Value<int> maxPlayers = const Value.absent(),
                Value<int> maxCommanders = const Value.absent(),
                Value<String> enabledCounterIds = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameFormatsCompanion(
                id: id,
                name: name,
                startingLife: startingLife,
                minPlayers: minPlayers,
                maxPlayers: maxPlayers,
                maxCommanders: maxCommanders,
                enabledCounterIds: enabledCounterIds,
                isBuiltIn: isBuiltIn,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> startingLife = const Value.absent(),
                Value<int> minPlayers = const Value.absent(),
                Value<int> maxPlayers = const Value.absent(),
                Value<int> maxCommanders = const Value.absent(),
                Value<String> enabledCounterIds = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameFormatsCompanion.insert(
                id: id,
                name: name,
                startingLife: startingLife,
                minPlayers: minPlayers,
                maxPlayers: maxPlayers,
                maxCommanders: maxCommanders,
                enabledCounterIds: enabledCounterIds,
                isBuiltIn: isBuiltIn,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameFormatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameFormatsTable,
      DbGameFormat,
      $$GameFormatsTableFilterComposer,
      $$GameFormatsTableOrderingComposer,
      $$GameFormatsTableAnnotationComposer,
      $$GameFormatsTableCreateCompanionBuilder,
      $$GameFormatsTableUpdateCompanionBuilder,
      (
        DbGameFormat,
        BaseReferences<_$AppDatabase, $GameFormatsTable, DbGameFormat>,
      ),
      DbGameFormat,
      PrefetchHooks Function()
    >;
typedef $$CounterTypesTableCreateCompanionBuilder =
    CounterTypesCompanion Function({
      required String id,
      required String name,
      Value<String> emoji,
      Value<int> color,
      Value<bool> isBuiltIn,
      Value<int?> maxValue,
      Value<int> rowid,
    });
typedef $$CounterTypesTableUpdateCompanionBuilder =
    CounterTypesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> emoji,
      Value<int> color,
      Value<bool> isBuiltIn,
      Value<int?> maxValue,
      Value<int> rowid,
    });

class $$CounterTypesTableFilterComposer
    extends Composer<_$AppDatabase, $CounterTypesTable> {
  $$CounterTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxValue => $composableBuilder(
    column: $table.maxValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CounterTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $CounterTypesTable> {
  $$CounterTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxValue => $composableBuilder(
    column: $table.maxValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CounterTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CounterTypesTable> {
  $$CounterTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  GeneratedColumn<int> get maxValue =>
      $composableBuilder(column: $table.maxValue, builder: (column) => column);
}

class $$CounterTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CounterTypesTable,
          DbCounterType,
          $$CounterTypesTableFilterComposer,
          $$CounterTypesTableOrderingComposer,
          $$CounterTypesTableAnnotationComposer,
          $$CounterTypesTableCreateCompanionBuilder,
          $$CounterTypesTableUpdateCompanionBuilder,
          (
            DbCounterType,
            BaseReferences<_$AppDatabase, $CounterTypesTable, DbCounterType>,
          ),
          DbCounterType,
          PrefetchHooks Function()
        > {
  $$CounterTypesTableTableManager(_$AppDatabase db, $CounterTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CounterTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CounterTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CounterTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int?> maxValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CounterTypesCompanion(
                id: id,
                name: name,
                emoji: emoji,
                color: color,
                isBuiltIn: isBuiltIn,
                maxValue: maxValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> emoji = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int?> maxValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CounterTypesCompanion.insert(
                id: id,
                name: name,
                emoji: emoji,
                color: color,
                isBuiltIn: isBuiltIn,
                maxValue: maxValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CounterTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CounterTypesTable,
      DbCounterType,
      $$CounterTypesTableFilterComposer,
      $$CounterTypesTableOrderingComposer,
      $$CounterTypesTableAnnotationComposer,
      $$CounterTypesTableCreateCompanionBuilder,
      $$CounterTypesTableUpdateCompanionBuilder,
      (
        DbCounterType,
        BaseReferences<_$AppDatabase, $CounterTypesTable, DbCounterType>,
      ),
      DbCounterType,
      PrefetchHooks Function()
    >;
typedef $$PlayerConfigsTableCreateCompanionBuilder =
    PlayerConfigsCompanion Function({
      required String id,
      required String name,
      Value<String> type,
      Value<int> colorValue,
      Value<String?> avatarPath,
      Value<String?> linkedDeckId,
      Value<int> rowid,
    });
typedef $$PlayerConfigsTableUpdateCompanionBuilder =
    PlayerConfigsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<int> colorValue,
      Value<String?> avatarPath,
      Value<String?> linkedDeckId,
      Value<int> rowid,
    });

final class $$PlayerConfigsTableReferences
    extends BaseReferences<_$AppDatabase, $PlayerConfigsTable, DbPlayerConfig> {
  $$PlayerConfigsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $PlayerConfigCommandersTable,
    List<DbPlayerConfigCommander>
  >
  _playerConfigCommandersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playerConfigCommanders,
        aliasName: $_aliasNameGenerator(
          db.playerConfigs.id,
          db.playerConfigCommanders.playerConfigId,
        ),
      );

  $$PlayerConfigCommandersTableProcessedTableManager
  get playerConfigCommandersRefs {
    final manager = $$PlayerConfigCommandersTableTableManager(
      $_db,
      $_db.playerConfigCommanders,
    ).filter((f) => f.playerConfigId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playerConfigCommandersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlayerConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $PlayerConfigsTable> {
  $$PlayerConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedDeckId => $composableBuilder(
    column: $table.linkedDeckId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playerConfigCommandersRefs(
    Expression<bool> Function($$PlayerConfigCommandersTableFilterComposer f) f,
  ) {
    final $$PlayerConfigCommandersTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playerConfigCommanders,
          getReferencedColumn: (t) => t.playerConfigId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlayerConfigCommandersTableFilterComposer(
                $db: $db,
                $table: $db.playerConfigCommanders,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlayerConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayerConfigsTable> {
  $$PlayerConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedDeckId => $composableBuilder(
    column: $table.linkedDeckId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayerConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayerConfigsTable> {
  $$PlayerConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedDeckId => $composableBuilder(
    column: $table.linkedDeckId,
    builder: (column) => column,
  );

  Expression<T> playerConfigCommandersRefs<T extends Object>(
    Expression<T> Function($$PlayerConfigCommandersTableAnnotationComposer a) f,
  ) {
    final $$PlayerConfigCommandersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playerConfigCommanders,
          getReferencedColumn: (t) => t.playerConfigId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlayerConfigCommandersTableAnnotationComposer(
                $db: $db,
                $table: $db.playerConfigCommanders,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlayerConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayerConfigsTable,
          DbPlayerConfig,
          $$PlayerConfigsTableFilterComposer,
          $$PlayerConfigsTableOrderingComposer,
          $$PlayerConfigsTableAnnotationComposer,
          $$PlayerConfigsTableCreateCompanionBuilder,
          $$PlayerConfigsTableUpdateCompanionBuilder,
          (DbPlayerConfig, $$PlayerConfigsTableReferences),
          DbPlayerConfig,
          PrefetchHooks Function({bool playerConfigCommandersRefs})
        > {
  $$PlayerConfigsTableTableManager(_$AppDatabase db, $PlayerConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayerConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayerConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayerConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<String?> linkedDeckId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerConfigsCompanion(
                id: id,
                name: name,
                type: type,
                colorValue: colorValue,
                avatarPath: avatarPath,
                linkedDeckId: linkedDeckId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> type = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<String?> linkedDeckId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerConfigsCompanion.insert(
                id: id,
                name: name,
                type: type,
                colorValue: colorValue,
                avatarPath: avatarPath,
                linkedDeckId: linkedDeckId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlayerConfigsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerConfigCommandersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playerConfigCommandersRefs) db.playerConfigCommanders,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playerConfigCommandersRefs)
                    await $_getPrefetchedData<
                      DbPlayerConfig,
                      $PlayerConfigsTable,
                      DbPlayerConfigCommander
                    >(
                      currentTable: table,
                      referencedTable: $$PlayerConfigsTableReferences
                          ._playerConfigCommandersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlayerConfigsTableReferences(
                            db,
                            table,
                            p0,
                          ).playerConfigCommandersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.playerConfigId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlayerConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayerConfigsTable,
      DbPlayerConfig,
      $$PlayerConfigsTableFilterComposer,
      $$PlayerConfigsTableOrderingComposer,
      $$PlayerConfigsTableAnnotationComposer,
      $$PlayerConfigsTableCreateCompanionBuilder,
      $$PlayerConfigsTableUpdateCompanionBuilder,
      (DbPlayerConfig, $$PlayerConfigsTableReferences),
      DbPlayerConfig,
      PrefetchHooks Function({bool playerConfigCommandersRefs})
    >;
typedef $$PlayerConfigCommandersTableCreateCompanionBuilder =
    PlayerConfigCommandersCompanion Function({
      required String id,
      required String playerConfigId,
      required String name,
      Value<String?> scryfallId,
      Value<String?> artCropUrl,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$PlayerConfigCommandersTableUpdateCompanionBuilder =
    PlayerConfigCommandersCompanion Function({
      Value<String> id,
      Value<String> playerConfigId,
      Value<String> name,
      Value<String?> scryfallId,
      Value<String?> artCropUrl,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$PlayerConfigCommandersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlayerConfigCommandersTable,
          DbPlayerConfigCommander
        > {
  $$PlayerConfigCommandersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayerConfigsTable _playerConfigIdTable(_$AppDatabase db) =>
      db.playerConfigs.createAlias(
        $_aliasNameGenerator(
          db.playerConfigCommanders.playerConfigId,
          db.playerConfigs.id,
        ),
      );

  $$PlayerConfigsTableProcessedTableManager get playerConfigId {
    final $_column = $_itemColumn<String>('player_config_id')!;

    final manager = $$PlayerConfigsTableTableManager(
      $_db,
      $_db.playerConfigs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerConfigIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlayerConfigCommandersTableFilterComposer
    extends Composer<_$AppDatabase, $PlayerConfigCommandersTable> {
  $$PlayerConfigCommandersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artCropUrl => $composableBuilder(
    column: $table.artCropUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayerConfigsTableFilterComposer get playerConfigId {
    final $$PlayerConfigsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerConfigId,
      referencedTable: $db.playerConfigs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayerConfigsTableFilterComposer(
            $db: $db,
            $table: $db.playerConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayerConfigCommandersTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayerConfigCommandersTable> {
  $$PlayerConfigCommandersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artCropUrl => $composableBuilder(
    column: $table.artCropUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayerConfigsTableOrderingComposer get playerConfigId {
    final $$PlayerConfigsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerConfigId,
      referencedTable: $db.playerConfigs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayerConfigsTableOrderingComposer(
            $db: $db,
            $table: $db.playerConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayerConfigCommandersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayerConfigCommandersTable> {
  $$PlayerConfigCommandersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get scryfallId => $composableBuilder(
    column: $table.scryfallId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artCropUrl => $composableBuilder(
    column: $table.artCropUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$PlayerConfigsTableAnnotationComposer get playerConfigId {
    final $$PlayerConfigsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerConfigId,
      referencedTable: $db.playerConfigs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayerConfigsTableAnnotationComposer(
            $db: $db,
            $table: $db.playerConfigs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayerConfigCommandersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayerConfigCommandersTable,
          DbPlayerConfigCommander,
          $$PlayerConfigCommandersTableFilterComposer,
          $$PlayerConfigCommandersTableOrderingComposer,
          $$PlayerConfigCommandersTableAnnotationComposer,
          $$PlayerConfigCommandersTableCreateCompanionBuilder,
          $$PlayerConfigCommandersTableUpdateCompanionBuilder,
          (DbPlayerConfigCommander, $$PlayerConfigCommandersTableReferences),
          DbPlayerConfigCommander,
          PrefetchHooks Function({bool playerConfigId})
        > {
  $$PlayerConfigCommandersTableTableManager(
    _$AppDatabase db,
    $PlayerConfigCommandersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayerConfigCommandersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PlayerConfigCommandersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlayerConfigCommandersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> playerConfigId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> scryfallId = const Value.absent(),
                Value<String?> artCropUrl = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerConfigCommandersCompanion(
                id: id,
                playerConfigId: playerConfigId,
                name: name,
                scryfallId: scryfallId,
                artCropUrl: artCropUrl,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String playerConfigId,
                required String name,
                Value<String?> scryfallId = const Value.absent(),
                Value<String?> artCropUrl = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerConfigCommandersCompanion.insert(
                id: id,
                playerConfigId: playerConfigId,
                name: name,
                scryfallId: scryfallId,
                artCropUrl: artCropUrl,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlayerConfigCommandersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerConfigId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerConfigId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playerConfigId,
                                referencedTable:
                                    $$PlayerConfigCommandersTableReferences
                                        ._playerConfigIdTable(db),
                                referencedColumn:
                                    $$PlayerConfigCommandersTableReferences
                                        ._playerConfigIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlayerConfigCommandersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayerConfigCommandersTable,
      DbPlayerConfigCommander,
      $$PlayerConfigCommandersTableFilterComposer,
      $$PlayerConfigCommandersTableOrderingComposer,
      $$PlayerConfigCommandersTableAnnotationComposer,
      $$PlayerConfigCommandersTableCreateCompanionBuilder,
      $$PlayerConfigCommandersTableUpdateCompanionBuilder,
      (DbPlayerConfigCommander, $$PlayerConfigCommandersTableReferences),
      DbPlayerConfigCommander,
      PrefetchHooks Function({bool playerConfigId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CollectionCardsTableTableManager get collectionCards =>
      $$CollectionCardsTableTableManager(_db, _db.collectionCards);
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db, _db.decks);
  $$DeckCardsTableTableManager get deckCards =>
      $$DeckCardsTableTableManager(_db, _db.deckCards);
  $$WishlistsTableTableManager get wishlists =>
      $$WishlistsTableTableManager(_db, _db.wishlists);
  $$WishlistCardsTableTableManager get wishlistCards =>
      $$WishlistCardsTableTableManager(_db, _db.wishlistCards);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$GameHistoryItemsTableTableManager get gameHistoryItems =>
      $$GameHistoryItemsTableTableManager(_db, _db.gameHistoryItems);
  $$ScanHistoryItemsTableTableManager get scanHistoryItems =>
      $$ScanHistoryItemsTableTableManager(_db, _db.scanHistoryItems);
  $$CollectionValueHistoryTableTableManager get collectionValueHistory =>
      $$CollectionValueHistoryTableTableManager(
        _db,
        _db.collectionValueHistory,
      );
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$GameFormatsTableTableManager get gameFormats =>
      $$GameFormatsTableTableManager(_db, _db.gameFormats);
  $$CounterTypesTableTableManager get counterTypes =>
      $$CounterTypesTableTableManager(_db, _db.counterTypes);
  $$PlayerConfigsTableTableManager get playerConfigs =>
      $$PlayerConfigsTableTableManager(_db, _db.playerConfigs);
  $$PlayerConfigCommandersTableTableManager get playerConfigCommanders =>
      $$PlayerConfigCommandersTableTableManager(
        _db,
        _db.playerConfigCommanders,
      );
}
