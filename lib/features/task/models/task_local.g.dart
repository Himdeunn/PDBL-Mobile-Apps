// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_local.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTaskLocalCollection on Isar {
  IsarCollection<TaskLocal> get taskLocals => this.collection();
}

const TaskLocalSchema = CollectionSchema(
  name: r'TaskLocal',
  id: -9072514404709919410,
  properties: {
    r'apiId': PropertySchema(id: 0, name: r'apiId', type: IsarType.long),
    r'assignedEmails': PropertySchema(
      id: 1,
      name: r'assignedEmails',
      type: IsarType.string,
    ),
    r'completedBy': PropertySchema(
      id: 2,
      name: r'completedBy',
      type: IsarType.string,
    ),
    r'description': PropertySchema(
      id: 3,
      name: r'description',
      type: IsarType.string,
    ),
    r'dueDate': PropertySchema(
      id: 4,
      name: r'dueDate',
      type: IsarType.dateTime,
    ),
    r'dueTime': PropertySchema(id: 5, name: r'dueTime', type: IsarType.string),
    r'isCompleted': PropertySchema(
      id: 6,
      name: r'isCompleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(id: 7, name: r'isSynced', type: IsarType.bool),
    r'lastLocalUpdate': PropertySchema(
      id: 8,
      name: r'lastLocalUpdate',
      type: IsarType.long,
    ),
    r'priority': PropertySchema(
      id: 9,
      name: r'priority',
      type: IsarType.string,
    ),
    r'teamId': PropertySchema(id: 10, name: r'teamId', type: IsarType.long),
    r'title': PropertySchema(id: 11, name: r'title', type: IsarType.string),
    r'totalAssigned': PropertySchema(
      id: 12,
      name: r'totalAssigned',
      type: IsarType.long,
    ),
    r'userEmail': PropertySchema(
      id: 13,
      name: r'userEmail',
      type: IsarType.string,
    ),
  },

  estimateSize: _taskLocalEstimateSize,
  serialize: _taskLocalSerialize,
  deserialize: _taskLocalDeserialize,
  deserializeProp: _taskLocalDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _taskLocalGetId,
  getLinks: _taskLocalGetLinks,
  attach: _taskLocalAttach,
  version: '3.3.2',
);

int _taskLocalEstimateSize(
  TaskLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.assignedEmails;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.completedBy;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.description;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.dueTime;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.priority.length * 3;
  bytesCount += 3 + object.title.length * 3;
  {
    final value = object.userEmail;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _taskLocalSerialize(
  TaskLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.apiId);
  writer.writeString(offsets[1], object.assignedEmails);
  writer.writeString(offsets[2], object.completedBy);
  writer.writeString(offsets[3], object.description);
  writer.writeDateTime(offsets[4], object.dueDate);
  writer.writeString(offsets[5], object.dueTime);
  writer.writeBool(offsets[6], object.isCompleted);
  writer.writeBool(offsets[7], object.isSynced);
  writer.writeLong(offsets[8], object.lastLocalUpdate);
  writer.writeString(offsets[9], object.priority);
  writer.writeLong(offsets[10], object.teamId);
  writer.writeString(offsets[11], object.title);
  writer.writeLong(offsets[12], object.totalAssigned);
  writer.writeString(offsets[13], object.userEmail);
}

TaskLocal _taskLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TaskLocal();
  object.apiId = reader.readLongOrNull(offsets[0]);
  object.assignedEmails = reader.readStringOrNull(offsets[1]);
  object.completedBy = reader.readStringOrNull(offsets[2]);
  object.description = reader.readStringOrNull(offsets[3]);
  object.dueDate = reader.readDateTimeOrNull(offsets[4]);
  object.dueTime = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.isCompleted = reader.readBool(offsets[6]);
  object.isSynced = reader.readBool(offsets[7]);
  object.lastLocalUpdate = reader.readLong(offsets[8]);
  object.priority = reader.readString(offsets[9]);
  object.teamId = reader.readLongOrNull(offsets[10]);
  object.title = reader.readString(offsets[11]);
  object.totalAssigned = reader.readLong(offsets[12]);
  object.userEmail = reader.readStringOrNull(offsets[13]);
  return object;
}

P _taskLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _taskLocalGetId(TaskLocal object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _taskLocalGetLinks(TaskLocal object) {
  return [];
}

void _taskLocalAttach(IsarCollection<dynamic> col, Id id, TaskLocal object) {
  object.id = id;
}

extension TaskLocalQueryWhereSort
    on QueryBuilder<TaskLocal, TaskLocal, QWhere> {
  QueryBuilder<TaskLocal, TaskLocal, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TaskLocalQueryWhere
    on QueryBuilder<TaskLocal, TaskLocal, QWhereClause> {
  QueryBuilder<TaskLocal, TaskLocal, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension TaskLocalQueryFilter
    on QueryBuilder<TaskLocal, TaskLocal, QFilterCondition> {
  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> apiIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'apiId'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> apiIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'apiId'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> apiIdEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'apiId', value: value),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> apiIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'apiId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> apiIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'apiId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> apiIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'apiId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'assignedEmails'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'assignedEmails'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'assignedEmails',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'assignedEmails',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'assignedEmails',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'assignedEmails',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'assignedEmails',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'assignedEmails',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'assignedEmails',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'assignedEmails',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'assignedEmails', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  assignedEmailsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'assignedEmails', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  completedByIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'completedBy'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  completedByIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'completedBy'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> completedByEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'completedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  completedByGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'completedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> completedByLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'completedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> completedByBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'completedBy',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  completedByStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'completedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> completedByEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'completedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> completedByContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'completedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> completedByMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'completedBy',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  completedByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'completedBy', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  completedByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'completedBy', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'description'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'description'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> descriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  descriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> descriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> descriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'description',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  descriptionStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> descriptionContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> descriptionMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'description',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'dueDate'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'dueDate'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueDateEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dueDate', value: value),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dueDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dueDate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dueDate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'dueTime'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'dueTime'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dueTime',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dueTime',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dueTime',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dueTime',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'dueTime',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'dueTime',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'dueTime',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'dueTime',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> dueTimeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dueTime', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  dueTimeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'dueTime', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> isCompletedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isCompleted', value: value),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> isSyncedEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isSynced', value: value),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  lastLocalUpdateEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastLocalUpdate', value: value),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  lastLocalUpdateGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastLocalUpdate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  lastLocalUpdateLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastLocalUpdate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  lastLocalUpdateBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastLocalUpdate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> priorityEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'priority',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> priorityGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'priority',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> priorityLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'priority',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> priorityBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'priority',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> priorityStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'priority',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> priorityEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'priority',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> priorityContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'priority',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> priorityMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'priority',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> priorityIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'priority', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  priorityIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'priority', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> teamIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'teamId'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> teamIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'teamId'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> teamIdEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'teamId', value: value),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> teamIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'teamId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> teamIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'teamId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> teamIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'teamId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  totalAssignedEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'totalAssigned', value: value),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  totalAssignedGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalAssigned',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  totalAssignedLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalAssigned',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  totalAssignedBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalAssigned',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> userEmailIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'userEmail'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  userEmailIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'userEmail'),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> userEmailEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'userEmail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  userEmailGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'userEmail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> userEmailLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'userEmail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> userEmailBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'userEmail',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> userEmailStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'userEmail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> userEmailEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'userEmail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> userEmailContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'userEmail',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> userEmailMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'userEmail',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition> userEmailIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'userEmail', value: ''),
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterFilterCondition>
  userEmailIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'userEmail', value: ''),
      );
    });
  }
}

extension TaskLocalQueryObject
    on QueryBuilder<TaskLocal, TaskLocal, QFilterCondition> {}

extension TaskLocalQueryLinks
    on QueryBuilder<TaskLocal, TaskLocal, QFilterCondition> {}

extension TaskLocalQuerySortBy on QueryBuilder<TaskLocal, TaskLocal, QSortBy> {
  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByApiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'apiId', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByApiIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'apiId', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByAssignedEmails() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedEmails', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByAssignedEmailsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedEmails', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByCompletedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedBy', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByCompletedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedBy', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByDueDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueDate', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByDueDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueDate', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByDueTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueTime', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByDueTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueTime', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByIsCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByLastLocalUpdate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalUpdate', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByLastLocalUpdateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalUpdate', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByPriority() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByPriorityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByTeamId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'teamId', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByTeamIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'teamId', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByTotalAssigned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAssigned', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByTotalAssignedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAssigned', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByUserEmail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userEmail', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> sortByUserEmailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userEmail', Sort.desc);
    });
  }
}

extension TaskLocalQuerySortThenBy
    on QueryBuilder<TaskLocal, TaskLocal, QSortThenBy> {
  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByApiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'apiId', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByApiIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'apiId', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByAssignedEmails() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedEmails', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByAssignedEmailsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assignedEmails', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByCompletedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedBy', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByCompletedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedBy', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByDueDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueDate', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByDueDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueDate', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByDueTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueTime', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByDueTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueTime', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByIsCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByLastLocalUpdate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalUpdate', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByLastLocalUpdateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalUpdate', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByPriority() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByPriorityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priority', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByTeamId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'teamId', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByTeamIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'teamId', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByTotalAssigned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAssigned', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByTotalAssignedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAssigned', Sort.desc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByUserEmail() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userEmail', Sort.asc);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QAfterSortBy> thenByUserEmailDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userEmail', Sort.desc);
    });
  }
}

extension TaskLocalQueryWhereDistinct
    on QueryBuilder<TaskLocal, TaskLocal, QDistinct> {
  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByApiId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'apiId');
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByAssignedEmails({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'assignedEmails',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByCompletedBy({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByDescription({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByDueDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dueDate');
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByDueTime({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dueTime', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isCompleted');
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByLastLocalUpdate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastLocalUpdate');
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByPriority({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'priority', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByTeamId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'teamId');
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByTotalAssigned() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalAssigned');
    });
  }

  QueryBuilder<TaskLocal, TaskLocal, QDistinct> distinctByUserEmail({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userEmail', caseSensitive: caseSensitive);
    });
  }
}

extension TaskLocalQueryProperty
    on QueryBuilder<TaskLocal, TaskLocal, QQueryProperty> {
  QueryBuilder<TaskLocal, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TaskLocal, int?, QQueryOperations> apiIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'apiId');
    });
  }

  QueryBuilder<TaskLocal, String?, QQueryOperations> assignedEmailsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assignedEmails');
    });
  }

  QueryBuilder<TaskLocal, String?, QQueryOperations> completedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedBy');
    });
  }

  QueryBuilder<TaskLocal, String?, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<TaskLocal, DateTime?, QQueryOperations> dueDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dueDate');
    });
  }

  QueryBuilder<TaskLocal, String?, QQueryOperations> dueTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dueTime');
    });
  }

  QueryBuilder<TaskLocal, bool, QQueryOperations> isCompletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isCompleted');
    });
  }

  QueryBuilder<TaskLocal, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<TaskLocal, int, QQueryOperations> lastLocalUpdateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastLocalUpdate');
    });
  }

  QueryBuilder<TaskLocal, String, QQueryOperations> priorityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'priority');
    });
  }

  QueryBuilder<TaskLocal, int?, QQueryOperations> teamIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'teamId');
    });
  }

  QueryBuilder<TaskLocal, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<TaskLocal, int, QQueryOperations> totalAssignedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalAssigned');
    });
  }

  QueryBuilder<TaskLocal, String?, QQueryOperations> userEmailProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userEmail');
    });
  }
}
