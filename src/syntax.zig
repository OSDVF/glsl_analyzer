//! Provides easy type-safe access and traversals of the nodes of a parse tree.

const syntax = @This();

const std = @import("std");
const parse = @import("parse.zig");
const Tree = parse.Tree;
const Tag = parse.Tag;

pub const File = ListExtractor(.file, null, ExternalDeclaration, null);

/// Declaration of a visible symbol / type
pub const AnyDeclaration = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;
    function: FunctionDeclaration,
    variable: Declaration,
    block: BlockDeclaration,
    parameter: Parameter,
    struct_specifier: StructSpecifier,
};

pub const ExternalDeclaration = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    function: FunctionDeclaration,
    variable: Declaration,
    block: BlockDeclaration,
};

pub const FunctionDeclaration = Extractor(.function_declaration, struct {
    qualifiers: QualifierList,
    specifier: TypeSpecifier,
    identifier: Token(.identifier),
    parameters: ParameterList,
    block: Block,
    semi: Token(.@";"),
});

/// Arguments of a function call (not a function declaration)
pub const ArgumentsList = ListExtractor(.arguments_list, Token(.@"("), Argument, Token(.@")"));

pub const Call = Extractor(.call, struct {
    identifier: Token(.identifier),
    arguments: ArgumentsList,
});

/// Parameters of a function declaration (not a function call)
pub const ParameterList = ListExtractor(.parameter_list, Token(.@"("), Parameter, Token(.@")"));

/// Parameter of a function declaration (not a function call)
pub const Parameter = Extractor(.parameter, struct {
    qualifiers: QualifierList,
    specifier: TypeSpecifier,
    variable: VariableDeclaration,
    comma: Token(.@","),
});

pub const BlockDeclaration = Extractor(.block_declaration, struct {
    qualifiers: QualifierList,
    specifier: TypeSpecifier,
    fields: FieldList,
    variable: VariableDeclaration,
    semi: Token(.@";"),
});

pub const ConditionalExpression = Extractor(.conditional, struct {
    condition: Expression,
    @"?": Token(.@"?"),
    true_expr: Expression,
    @":": Token(.@":"),
    false_expr: Expression,
});

pub const Declaration = Extractor(.declaration, struct {
    qualifiers: QualifierList,
    specifier: TypeSpecifier,
    variables: Variables,
    semi: Token(.@";"),
});

pub const Variables = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;
    one: VariableDeclaration,
    many: VariableDeclarationList,

    pub const Iterator = union(enum) {
        one: ?VariableDeclaration,
        many: VariableDeclarationList.Iterator,

        pub fn next(self: *@This(), tree: Tree) ?VariableDeclaration {
            switch (self.*) {
                .one => |*one| {
                    const value = one.*;
                    one.* = null;
                    return value;
                },
                .many => |*many| {
                    return many.next(tree);
                },
            }
        }
    };

    pub fn iterator(self: @This()) Iterator {
        return switch (self) {
            .one => |one| .{ .one = one },
            .many => |many| .{ .many = many.iterator() },
        };
    }
};

pub const VariableDeclarationList = ListExtractor(.variable_declaration_list, null, VariableDeclaration, null);

pub const VariableDeclaration = Extractor(.variable_declaration, struct {
    name: VariableName,
    eq_token: Token(.@"="),
    initializer: Initializer,
    comma: Token(.@","),
});

pub const VariableName = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    identifier: Token(.identifier),
    array: ArraySpecifierName,

    pub fn getIdentifier(self: @This(), tree: Tree) ?Token(.identifier) {
        return switch (self) {
            .identifier => |token| token,
            .array => |array| array.prefix(tree),
        };
    }

    pub fn arrayIterator(self: @This()) ?ListIterator(Array) {
        return switch (self) {
            .identifier => null,
            .array => |array| array.iterator(),
        };
    }
};

pub const Initializer = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    list: InitializerList,
    expr: Expression,
};

pub const InitializerList = ListExtractor(.initializer_list, Token(.@"{"), Initializer, Token(.@"}"));

pub const QualifierList = ListExtractor(.type_qualifier_list, null, Qualifier, null);

pub const Qualifier = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    storage: StorageQualifier,
    layout: LayoutQualifier,
    precision: PrecisionQualifier,
    interpolation: InterpolationQualifier,
    invariant: Token(.keyword_invariant),
    precise: Token(.keyword_precise),
    subroutine: SubroutineQualifier,
};

pub const StorageQualifier = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    @"const": Token(.keyword_const),
    attribute: Token(.keyword_attribute),
    uniform: Token(.keyword_uniform),
    varying: Token(.keyword_varying),
    buffer: Token(.keyword_buffer),
    shared: Token(.keyword_shared),
    coherent: Token(.keyword_coherent),
    @"volatile": Token(.keyword_volatile),
    restrict: Token(.keyword_restrict),
    readonly: Token(.keyword_readonly),
    writeonly: Token(.keyword_writeonly),
    in: Token(.keyword_in),
    out: Token(.keyword_out),
    inout: Token(.keyword_inout),
    patch: Token(.keyword_patch),
    sample: Token(.keyword_sample),
};

pub const LayoutQualifier = Extractor(.layout_qualifier, struct {
    keyword_layout: Token(.keyword_layout),
    layout_qualifiers: LayoutQualifierList,
});

pub const LayoutQualifierList = ListExtractor(.layout_qualifiers_list, Token(.@"("), LayoutQualifierItem, Token(.@")"));

pub const LayoutQualifierItem = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    assignment: Assignment,
    other: union(enum) {
        pub const e = UnionExtractorMixin(@This());
        pub const extract = e.extract;
        pub const getNode = e.getNode;
        pub const match = e.match;
        pub const tryExtract = e.extractor.tryExtract;
    },
};

pub const Assignment = Extractor(.assignment, struct {
    identifier: Token(.identifier),
    eq: AssignmentOperator,
    value: Expression,
});

pub const PrecisionQualifier = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    highp: Token(.keyword_highp),
    mediump: Token(.keyword_mediump),
    lowp: Token(.keyword_lowp),
};

pub const InterpolationQualifier = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    smooth: Token(.keyword_smooth),
    flat: Token(.keyword_flat),
    noperspective: Token(.keyword_noperspective),
    centroid: Token(.keyword_centroid),
};

pub const SubroutineQualifier = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;
};

pub const TypeSpecifier = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    identifier: Token(.identifier),
    array_specifier: ArraySpecifierName,
    struct_specifier: StructSpecifier,

    pub fn underlyingName(self: @This(), tree: Tree) ?Token(.identifier) {
        switch (self) {
            .identifier => |ident| return ident,
            .array_specifier => |array| return array.prefix(tree),
            else => return null,
        }
    }
};

pub const StructSpecifier = Extractor(.struct_specifier, struct {
    keyword_struct: Token(.keyword_struct),
    name: Token(.identifier),
    /// Struct fields may contain structs themselves, so we need lazy indirection here.
    fields: Lazy("FieldList"),
});

pub const FieldList = ListExtractor(.field_declaration_list, Token(.@"{"), Declaration, Token(.@"}"));

pub const ArraySpecifierName = ArraySpecifier(Token(.identifier));

pub fn ArraySpecifier(comptime Prefix: type) type {
    return ListExtractor(.array_specifier, Prefix, Array, null);
}

pub const Array = Extractor(.array, struct {
    open: Token(.@"["),
    value: Expression,
    close: Token(.@"]"),
});

pub const Block = ListExtractor(.block, Token(.@"{"), Statement, Token(.@"}"));

pub const Statement = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    pub fn node(self: @This()) u32 {
        return self.declaration.node;
    }

    declaration: Declaration,
};

pub const ConditionList = ListExtractor(.condition_list, Token(.@"("), Statement, Token(.@")"));

pub const Expression = Lazy("ExpressionUnion");

/// Argument of a function call (not a function declaration)
pub const Argument = Extractor(.argument, struct {
    expression: Expression,
});

pub const Selectable = Lazy("SelectableUnion");

pub const SelectableUnion = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    identifier: Token(.identifier),
    array: ArraySpecifier(Selectable),
    selection: Selection,
    call: Call,
};

pub const ExpressionUnion = union(enum) {
    pub const extractor = UnionExtractorMixin(@This());
    pub const extract = extractor.extract;
    pub const getNode = extractor.getNode;
    pub const match = extractor.match;
    pub const tryExtract = extractor.extractor.tryExtract;

    array: ArraySpecifier(Selectable),
    assignment: Assignment,
    call: Call,
    conditional: ConditionalExpression,
    identifier: Token(.identifier),
    infix: InfixExpression,
    number: Token(.number),
    parenthized: Parenthized,
    postfix: PostfixExpression,
    prefix: PrefixExpression,
    selection: Selection,
    sequence: Sequence,
};

pub const Sequence = ListExtractor(.expression_sequence, Token(.@"("), Expression, Token(.@")"));

pub const Parenthized = Extractor(.parenthized, struct {
    open: Token(.@"("),
    expression: Expression,
    close: Token(.@")"),
});

pub const InfixExpression = Extractor(.infix, struct {
    left: Expression,
    op: InfixOperator,
    right: Expression,
});

pub const PostfixExpression = Extractor(.postfix, struct {
    expression: Expression,
    op: UnaryOperator,
});

pub const PrefixExpression = Extractor(.prefix, struct {
    op: UnaryOperator,
    expression: Expression,
});

pub const InfixOperator = TokenSetToSyntax(parse.infix_operators);
pub const AssignmentOperator = TokenSetToSyntax(parse.assignment_operators);
pub const UnaryOperator = TokenSetToSyntax(parse.unary_operators);

/// Converts a set of token-tags into a syntax extractor
fn TokenSetToSyntax(comptime set: std.EnumSet(parse.Tag)) type {
    var it = set.iterator();
    var u_fields: [set.count()]std.builtin.Type.UnionField = undefined;
    var e_fields: [set.count()]std.builtin.Type.EnumField = undefined;

    var i = 0;
    while (it.next()) |op| {
        u_fields[i] = std.builtin.Type.UnionField{
            .name = @tagName(op),
            .type = Token(op),
            .alignment = 0,
        };
        e_fields[i] = std.builtin.Type.EnumField{
            .name = @tagName(op),
            .value = @intFromEnum(op),
        };
        i += 1;
    }

    const u = @Type(.{ .@"union" = std.builtin.Type.Union{
        .fields = &u_fields,
        .decls = &.{},
        .layout = .auto,
        .tag_type = @Type(.{ .@"enum" = std.builtin.Type.Enum{
            .fields = &e_fields,
            .decls = &.{},
            .is_exhaustive = true,
            .tag_type = u8,
        } }),
    } });

    return UnionExtractorWrapper(u);
}

pub const Selection = Extractor(.selection, struct {
    target: Selectable,
    @".": Token(.@"."),
    field: Token(.identifier),
});

pub fn Token(comptime tag: Tag) type {
    comptime std.debug.assert(tag.isToken());
    return struct {
        pub const extractor = ExtractorMixin(@This());

        node: u32,

        pub fn match(tree: Tree, node: u32) ?void {
            return if (tree.tag(node) == tag) {} else null;
        }

        pub fn extract(_: Tree, node: u32, _: void) @This() {
            return .{ .node = node };
        }

        pub fn text(self: @This(), source: []const u8, tree: Tree) []const u8 {
            const span = tree.token(self.node);
            return source[span.start..span.end];
        }
    };
}

pub fn Extractor(comptime expected_tag: Tag, comptime T: type) type {
    const fields = std.meta.fields(T);

    return struct {
        pub const FieldEnum = std.meta.FieldEnum(T);
        pub const Type = T;

        const extractor = ExtractorMixin(@This());
        pub const tryExtract = extractor.tryExtract;

        fn Match(comptime FieldType: type) type {
            return struct {
                node_offset: ?u7 = null,
                result: MatchResult(FieldType) = undefined,
            };
        }

        const MatchFields = @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .fields = blk: {
                    var match_fields: [fields.len]std.builtin.Type.StructField = undefined;
                    for (&match_fields, fields) |*match_field, field| {
                        match_field.* = field;
                        match_field.type = Match(field.type);
                        match_field.default_value_ptr = &@as(match_field.type, .{});
                    }
                    break :blk &match_fields;
                },
                .decls = &.{},
                .is_tuple = false,
            },
        });

        node: u32,
        matches: MatchFields,

        pub fn match(tree: Tree, node: u32) ?void {
            return if (tree.tag(node) == expected_tag) {} else null;
        }

        pub fn extract(tree: Tree, node: u32, _: void) @This() {
            var matches = MatchFields{};

            const children = tree.children(node);
            var current = children.start;

            inline for (fields) |field| {
                while (current < children.end) : (current += 1) {
                    const tag = tree.tag(current);
                    if (field.type.match(tree, current)) |result| {
                        @field(matches, field.name) = .{
                            .node_offset = @intCast(current - children.start),
                            .result = result,
                        };
                        current += 1;
                        break;
                    } else {
                        if (tag == .invalid or tag == .unknown) continue;
                        break;
                    }
                }
            }

            return .{ .node = node, .matches = matches };
        }

        pub fn nodeOf(self: @This(), comptime field: FieldEnum, tree: Tree) ?u32 {
            const field_match = @field(self.matches, @tagName(field));
            const node_offset = field_match.node_offset orelse return null;
            return tree.children(self.node).start + node_offset;
        }

        pub fn get(self: @This(), comptime field: FieldEnum, tree: Tree) ?std.meta.FieldType(T, field) {
            const field_match = @field(self.matches, @tagName(field));
            const node_offset = field_match.node_offset orelse return null;
            const node = tree.children(self.node).start + node_offset;
            return std.meta.FieldType(T, field).extract(tree, node, field_match.result);
        }
    };
}

pub fn ListExtractor(comptime tag: Tag, comptime Prefix: ?type, comptime Item: type, comptime Suffix: ?type) type {
    const PrefixMatch = if (Prefix) |P| MatchResult(P) else noreturn;
    const SuffixMatch = if (Suffix) |S| MatchResult(S) else noreturn;

    return struct {
        pub const extractor = ExtractorMixin(@This());
        pub const tryExtract = extractor.tryExtract;

        const Self = @This();

        node: u32,
        prefix_match: ?PrefixMatch,
        suffix_match: ?SuffixMatch,
        items: parse.Range,

        pub fn match(tree: Tree, node: u32) ?void {
            return if (tag == tree.tag(node)) {} else null;
        }

        pub fn extract(tree: Tree, node: u32, _: void) @This() {
            const children = tree.children(node);

            const empty = children.start == children.end;

            const prefix_match: ?PrefixMatch = blk: {
                if (empty) break :blk null;
                if (Prefix) |P| break :blk P.match(tree, children.start);
                break :blk null;
            };

            const suffix_match: ?SuffixMatch = blk: {
                if (empty) break :blk null;
                if (Suffix) |S| break :blk S.match(tree, children.end - 1);
                break :blk null;
            };

            return .{
                .node = node,
                .prefix_match = prefix_match,
                .suffix_match = suffix_match,
                .items = .{
                    .start = children.start + @intFromBool(prefix_match != null),
                    .end = children.end - @intFromBool(suffix_match != null),
                },
            };
        }

        pub const prefix = if (Prefix) |PrefixType| struct {
            pub fn prefix(self: Self, tree: Tree) ?PrefixType {
                return PrefixType.extract(tree, self.items.start - 1, self.prefix_match orelse return null);
            }
        }.prefix else {};

        pub const suffix = if (Suffix) |SuffixType| struct {
            pub fn suffix(self: Self, tree: Tree) ?SuffixType {
                return SuffixType.extract(tree, self.items.end, self.suffix_match orelse return null);
            }
        }.suffix else {};

        pub const Iterator = ListIterator(Item);

        pub fn iterator(self: Self) Iterator {
            return .{
                .items = self.items,
            };
        }
    };
}

pub fn ListIterator(comptime Item: type) type {
    return struct {
        items: parse.Range,

        pub fn next(self: *@This(), tree: Tree) ?Item {
            while (self.items.start < self.items.end) {
                defer self.items.start += 1;
                if (Item.match(tree, self.items.start)) |res| {
                    return Item.extract(tree, self.items.start, res);
                }
            }
            return null;
        }
    };
}

pub fn UnionExtractorMixin(comptime Self: type) type {
    const fields = std.meta.fields(Self);

    return struct {
        pub const extractor = ExtractorMixin(Self);

        const MatchUnion = @Type(.{
            .@"union" = .{
                .layout = .auto,
                .fields = blk: {
                    var match_fields: [fields.len]std.builtin.Type.UnionField = undefined;

                    for (&match_fields, fields) |*match_field, field| {
                        match_field.* = .{
                            .name = field.name,
                            .type = MatchResult(field.type),
                            .alignment = 0,
                        };
                    }

                    break :blk &match_fields;
                },
                .tag_type = std.meta.Tag(Self),
                .decls = &.{},
            },
        });

        pub fn match(tree: Tree, node: u32) ?MatchUnion {
            inline for (fields) |field| {
                if (field.type.match(tree, node)) |value| {
                    return @unionInit(MatchUnion, field.name, value);
                }
            }
            return null;
        }

        pub fn extract(tree: Tree, node: u32, result: MatchUnion) Self {
            if (fields.len == 0) return undefined;

            switch (std.meta.activeTag(result)) {
                inline else => |res| {
                    const name = @tagName(res);
                    const Inner = @TypeOf(@field(@as(Self, undefined), name));
                    return @unionInit(Self, name, Inner.extract(tree, node, @field(result, name)));
                },
            }
        }

        pub fn getNode(self: Self) u32 {
            if (fields.len == 0) return undefined;
            switch (self) {
                inline else => |value| {
                    if (@hasField(@TypeOf(value), "node")) return value.node;
                    return value.node();
                },
            }
        }
    };
}

pub fn UnionExtractorWrapper(comptime Self: type) type {
    const fields = std.meta.fields(Self);

    return struct {
        pub const extractor = ExtractorMixin(Self);

        inner: Self,

        const MatchUnion = @Type(.{
            .@"union" = .{
                .layout = .auto,
                .fields = blk: {
                    var match_fields: [fields.len]std.builtin.Type.UnionField = undefined;

                    for (&match_fields, fields) |*match_field, field| {
                        match_field.* = .{
                            .name = field.name,
                            .type = MatchResult(field.type),
                            .alignment = 0,
                        };
                    }

                    break :blk &match_fields;
                },
                .tag_type = std.meta.Tag(Self),
                .decls = &.{},
            },
        });

        pub fn match(tree: Tree, node: u32) ?MatchUnion {
            inline for (fields) |field| {
                if (field.type.match(tree, node)) |value| {
                    return @unionInit(MatchUnion, field.name, value);
                }
            }
            return null;
        }

        pub fn extract(tree: Tree, node: u32, result: MatchUnion) @This() {
            if (fields.len == 0) return undefined;

            switch (std.meta.activeTag(result)) {
                inline else => |res| {
                    const name = @tagName(res);
                    const Inner = @TypeOf(@field(@as(Self, undefined), name));
                    return .{ .inner = @unionInit(Self, name, Inner.extract(tree, node, @field(result, name))) };
                },
            }
        }

        pub fn getNode(self: @This()) u32 {
            if (fields.len == 0) return undefined;
            switch (self.inner) {
                inline else => |value| {
                    if (@hasField(@TypeOf(value), "node")) return value.node;
                    return value.node();
                },
            }
        }
    };
}

/// Break type-level dependency cycles through lazy-evaluation indirection.
pub fn Lazy(comptime type_name: []const u8) type {
    return struct {
        pub const extractor = ExtractorMixin(@This());

        node: u32,
        match_result_bytes: [4]u8,

        const Type = @field(syntax, type_name);
        const Match = MatchResult(Type);
        const MatchInt = std.meta.int(.unsigned, 8 * @sizeOf(Match));

        fn encodeMatchResult(res: Match) [4]u8 {
            switch (@sizeOf(Match)) {
                0...4 => return std.mem.toBytes(res) ++ [_]u8{0} ** (4 - @sizeOf(Match)),
                else => return .{ 0, 0, 0, 0 },
            }
        }

        fn decodeMatchResult(self: @This(), tree: Tree) Match {
            switch (@sizeOf(Match)) {
                0...4 => return std.mem.bytesToValue(Match, self.match_result_bytes[0..@sizeOf(Match)]),
                else => return Type.match(tree, self.node).?,
            }
        }

        pub fn match(tree: Tree, node: u32) ?[4]u8 {
            return encodeMatchResult(Type.match(tree, node) orelse return null);
        }

        pub fn extract(_: Tree, node: u32, match_result_bytes: [4]u8) @This() {
            return .{
                .node = node,
                .match_result_bytes = match_result_bytes,
            };
        }

        pub fn get(self: @This(), tree: Tree) Type {
            const match_result = self.decodeMatchResult(tree);
            return Type.extract(tree, self.node, match_result);
        }
    };
}

fn getMatchFnType(comptime T: type) type {
    if (@hasDecl(T, "match")) {
        return @TypeOf(T.match);
    } else if (@hasDecl(T, "extractor")) {
        return getMatchFnType(T.extractor);
    } else {
        @compileError("Type " ++ @typeName(T) ++ " has no match function");
    }
}

pub fn MatchResult(comptime T: type) type {
    const match_fn_return = @typeInfo(getMatchFnType(T)).@"fn".return_type.?;
    return @typeInfo(match_fn_return).optional.child;
}

pub fn ExtractorMixin(comptime Self: type) type {
    return struct {
        pub fn tryExtract(tree: Tree, node: u32) ?Self {
            const match_result = Self.match(tree, node) orelse return null;
            return Self.extract(tree, node, match_result);
        }
    };
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
