//===--- TypeCheckPropertyDelegate.cpp - Property Delegates ---------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file implements semantic analysis for property delegates.
//
//===----------------------------------------------------------------------===//
#include "TypeChecker.h"
#include "TypeCheckType.h"
#include "swift/AST/ASTContext.h"
#include "swift/AST/Decl.h"
#include "swift/AST/DiagnosticsSema.h"
#include "swift/AST/LazyResolver.h"
#include "swift/AST/NameLookupRequests.h"
#include "swift/AST/PropertyDelegates.h"
#include "swift/AST/TypeCheckRequests.h"
using namespace swift;

/// Find the named property in a property delegate to which access will
/// be delegated.
static VarDecl *findValueProperty(ASTContext &ctx, NominalTypeDecl *nominal,
                                  Identifier name, bool allowMissing) {
  SmallVector<VarDecl *, 2> vars;
  {
    SmallVector<ValueDecl *, 2> decls;
    nominal->lookupQualified(nominal, name, NL_QualifiedDefault, decls);
    for (const auto &foundDecl : decls) {
      auto foundVar = dyn_cast<VarDecl>(foundDecl);
      if (!foundVar || foundVar->isStatic() ||
          foundVar->getDeclContext() != nominal)
        continue;

      vars.push_back(foundVar);
    }
  }

  // Diagnose missing or ambiguous properties.
  switch (vars.size()) {
  case 0:
    if (!allowMissing) {
      nominal->diagnose(diag::property_delegate_no_value_property,
                        nominal->getDeclaredType(), name);
    }
    return nullptr;

  case 1:
    break;

  default:
    nominal->diagnose(diag::property_delegate_ambiguous_value_property,
                      nominal->getDeclaredType(), name);
    for (auto var : vars) {
      var->diagnose(diag::kind_declname_declared_here,
                    var->getDescriptiveKind(), var->getFullName());
    }
    return nullptr;
  }

  // The property must be as accessible as the nominal type.
  VarDecl *var = vars.front();
  if (var->getFormalAccess() < nominal->getFormalAccess()) {
    var->diagnose(diag::property_delegate_type_requirement_not_accessible,
                  var->getFormalAccess(), var->getDescriptiveKind(),
                  var->getFullName(), nominal->getDeclaredType(),
                  nominal->getFormalAccess());
    return nullptr;
  }

  return var;
}

/// Determine whether we have a suitable init(initialValue:) within a property
/// delegate type.
static ConstructorDecl *findInitialValueInit(ASTContext &ctx,
                                             NominalTypeDecl *nominal,
                                             VarDecl *valueVar) {
  SmallVector<ConstructorDecl *, 2> initialValueInitializers;
  DeclName initName(ctx, DeclBaseName::createConstructor(),
                    {ctx.Id_initialValue});
  SmallVector<ValueDecl *, 2> decls;
  nominal->lookupQualified(nominal, initName, NL_QualifiedDefault, decls);
  for (const auto &decl : decls) {
    auto init = dyn_cast<ConstructorDecl>(decl);
    if (!init || init->getDeclContext() != nominal)
      continue;

    initialValueInitializers.push_back(init);
  }

  switch (initialValueInitializers.size()) {
  case 0:
    return nullptr;

  case 1:
    break;

  default:
    // Diagnose ambiguous init(initialValue:) initializers.
    nominal->diagnose(diag::property_delegate_ambiguous_initial_value_init,
                      nominal->getDeclaredType());
    for (auto init : initialValueInitializers) {
      init->diagnose(diag::kind_declname_declared_here,
                     init->getDescriptiveKind(), init->getFullName());
    }
    return nullptr;
  }

  // 'init(initialValue:)' must be as accessible as the nominal type.
  auto init = initialValueInitializers.front();
  if (init->getFormalAccess() < nominal->getFormalAccess()) {
    init->diagnose(diag::property_delegate_type_requirement_not_accessible,
                     init->getFormalAccess(), init->getDescriptiveKind(),
                     init->getFullName(), nominal->getDeclaredType(),
                     nominal->getFormalAccess());
    return nullptr;
  }

  // Retrieve the type of the 'value' property.
  if (!valueVar->hasInterfaceType())
    ctx.getLazyResolver()->resolveDeclSignature(valueVar);
  Type valueVarType = valueVar->getValueInterfaceType();

  // Retrieve the parameter type of the initializer.
  if (!init->hasInterfaceType())
    ctx.getLazyResolver()->resolveDeclSignature(init);
  Type paramType;
  if (auto *curriedInitType =
          init->getInterfaceType()->getAs<AnyFunctionType>()) {
    if (auto *initType =
          curriedInitType->getResult()->getAs<AnyFunctionType>()) {
      if (initType->getParams().size() == 1) {
        const auto &param = initType->getParams()[0];
        if (!param.isInOut() && !param.isVariadic()) {
          paramType = param.getPlainType();
          if (param.isAutoClosure()) {
            if (auto *fnType = paramType->getAs<FunctionType>())
              paramType = fnType->getResult();
          }
        }
      }
    }
  }

  // The parameter type must be the same as the type of `valueVar` or an
  // autoclosure thereof.
  if (!paramType->isEqual(valueVarType)) {
    init->diagnose(diag::property_delegate_wrong_initial_value_init, paramType,
                   valueVarType);
    valueVar->diagnose(diag::decl_declared_here, valueVar->getFullName());
    return nullptr;
  }

  // The initializer must not be failable.
  if (init->getFailability() != OTK_None) {
    init->diagnose(diag::property_delegate_failable_initial_value_init);
    return nullptr;
  }

  return init;
}

llvm::Expected<PropertyDelegateTypeInfo>
PropertyDelegateTypeInfoRequest::evaluate(
    Evaluator &eval, NominalTypeDecl *nominal) const {
  // We must have the @_propertyDelegate attribute to continue.
  if (!nominal->getAttrs().hasAttribute<PropertyDelegateAttr>()) {
    return PropertyDelegateTypeInfo();
  }

  // Look for a non-static property named "value" in the property delegate
  // type.
  ASTContext &ctx = nominal->getASTContext();
  auto valueVar =
      findValueProperty(ctx, nominal, ctx.Id_value, /*allowMissing=*/false);
  if (!valueVar)
    return PropertyDelegateTypeInfo();

  PropertyDelegateTypeInfo result;
  result.valueVar = valueVar;
  result.initialValueInit = findInitialValueInit(ctx, nominal, valueVar);
  result.delegateValueVar =
    findValueProperty(ctx, nominal, ctx.Id_delegateValue, /*allowMissing=*/true);

  return result;
}

llvm::Expected<CustomAttr *>
AttachedPropertyDelegateRequest::evaluate(Evaluator &evaluator,
                                          VarDecl *var) const {
  ASTContext &ctx = var->getASTContext();
  auto dc = var->getDeclContext();
  for (auto attr : var->getAttrs().getAttributes<CustomAttr>()) {
    auto mutableAttr = const_cast<CustomAttr *>(attr);
    // Figure out which nominal declaration this custom attribute refers to.
    auto nominal = evaluateOrDefault(
      ctx.evaluator, CustomAttrNominalRequest{mutableAttr, dc}, nullptr);

    // If we didn't find a nominal type with a @_propertyDelegate attribute,
    // skip this custom attribute.
    if (!nominal || !nominal->getAttrs().hasAttribute<PropertyDelegateAttr>())
      continue;

    // Check various restrictions on which properties can have delegates
    // attached to them.

    // Local properties do not yet support delegates.
    if (var->getDeclContext()->isLocalContext()) {
      ctx.Diags.diagnose(attr->getLocation(), diag::property_delegate_local);
      return nullptr;
    }

    // Check that the variable is part of a single-variable pattern.
    auto binding = var->getParentPatternBinding();
    if (!binding || binding->getSingleVar() != var) {
      ctx.Diags.diagnose(attr->getLocation(),
                         diag::property_delegate_not_single_var);
      return nullptr;
    }

    // A property delegate cannot be attached to a 'let'.
    if (var->isLet()) {
      ctx.Diags.diagnose(attr->getLocation(), diag::property_delegate_let);
      return nullptr;
    }

    // Check for conflicting attributes.
    if (var->getAttrs().hasAttribute<LazyAttr>() ||
        var->getAttrs().hasAttribute<NSCopyingAttr>() ||
        var->getAttrs().hasAttribute<NSManagedAttr>() ||
        (var->getAttrs().hasAttribute<ReferenceOwnershipAttr>() &&
         var->getAttrs().getAttribute<ReferenceOwnershipAttr>()->get() !=
             ReferenceOwnership::Strong)) {
      int whichKind;
      if (var->getAttrs().hasAttribute<LazyAttr>())
        whichKind = 0;
      else if (var->getAttrs().hasAttribute<NSCopyingAttr>())
        whichKind = 1;
      else if (var->getAttrs().hasAttribute<NSManagedAttr>())
        whichKind = 2;
      else {
        auto attr = var->getAttrs().getAttribute<ReferenceOwnershipAttr>();
        whichKind = 2 + static_cast<unsigned>(attr->get());
      }
      var->diagnose(diag::property_with_delegate_conflict_attribute,
                    var->getFullName(), whichKind);
      return nullptr;
    }

    // A property with a delegate cannot be declared in a protocol, enum, or
    // an extension.
    if (isa<ProtocolDecl>(dc) ||
        (isa<ExtensionDecl>(dc) && var->isInstanceMember()) ||
        (isa<EnumDecl>(dc) && var->isInstanceMember())) {
      int whichKind;
      if (isa<ProtocolDecl>(dc))
        whichKind = 0;
      else if (isa<ExtensionDecl>(dc))
        whichKind = 1;
      else
        whichKind = 2;
      var->diagnose(diag::property_with_delegate_in_bad_context,
                    var->getFullName(), whichKind)
        .highlight(attr->getRange());

      return nullptr;
    }

    // Properties with delegates must not override another property.
    if (auto classDecl = dyn_cast<ClassDecl>(dc)) {
      if (auto overrideAttr = var->getAttrs().getAttribute<OverrideAttr>()) {
        var->diagnose(diag::property_with_delegate_overrides,
                      var->getFullName())
          .highlight(attr->getRange());
        return nullptr;
      }
    }

    return mutableAttr;
  }

  return nullptr;
}

llvm::Expected<Type>
AttachedPropertyDelegateTypeRequest::evaluate(Evaluator &evaluator,
                                              VarDecl *var) const {
  // Find the custom attribute for the attached property delegate.
  llvm::Expected<CustomAttr *> customAttrVal =
      evaluator(AttachedPropertyDelegateRequest{var});
  if (!customAttrVal)
    return customAttrVal.takeError();

  // If there isn't an attached property delegate, we're done.
  auto customAttr = *customAttrVal;
  if (!customAttr)
    return Type();

  auto resolution =
      TypeResolution::forContextual(var->getDeclContext());
  TypeResolutionOptions options(TypeResolverContext::PatternBindingDecl);
  options |= TypeResolutionFlags::AllowUnboundGenerics;

  ASTContext &ctx = var->getASTContext();
  auto &tc = *static_cast<TypeChecker *>(ctx.getLazyResolver());
  if (tc.validateType(customAttr->getTypeLoc(), resolution, options))
    return ErrorType::get(ctx);

  Type customAttrType = customAttr->getTypeLoc().getType();
  if (!customAttrType->getAnyNominal()) {
    assert(ctx.Diags.hadAnyError());
    return ErrorType::get(ctx);
  }

  return customAttrType;
}

llvm::Expected<Type>
PropertyDelegateBackingPropertyTypeRequest::evaluate(
                                    Evaluator &evaluator, VarDecl *var) const {
  llvm::Expected<Type> rawTypeResult =
    evaluator(AttachedPropertyDelegateTypeRequest{var});
  if (!rawTypeResult)
    return rawTypeResult;

  Type rawType = *rawTypeResult;
  if (!rawType)
    return Type();

  if (!rawType->hasUnboundGenericType())
    return rawType->mapTypeOutOfContext();

  auto binding = var->getParentPatternBinding();
  if (!binding)
    return Type();

  // If there's an initializer of some sort, checking it will determine the
  // property delegate type.
  unsigned index = binding->getPatternEntryIndexForVarDecl(var);
  ASTContext &ctx = var->getASTContext();
  TypeChecker &tc = *static_cast<TypeChecker *>(ctx.getLazyResolver());
  if (binding->isInitialized(index)) {
    tc.validateDecl(var);
    if (!binding->isInitializerChecked(index))
      tc.typeCheckPatternBinding(binding, index);

    Type type = ctx.getSideCachedPropertyDelegateBackingPropertyType(var);
    assert(type || ctx.Diags.hadAnyError());
    return type;
  }

  // Compose the type of property delegate with the type of the property.

  // We expect an unbound generic type here that refers to a single-parameter
  // generic type.
  auto delegateAttr = var->getAttachedPropertyDelegate();
  auto nominal = rawType->getAnyNominal();
  auto unboundGeneric = rawType->getAs<UnboundGenericType>();
  if (!unboundGeneric ||
      unboundGeneric->getDecl() != nominal ||
      !nominal->getGenericParams() ||
      nominal->getGenericParams()->size() != 1) {
    ctx.Diags.diagnose(delegateAttr->getLocation(),
                       diag::property_delegate_incompatible_unbound,
                       rawType)
      .highlight(delegateAttr->getTypeLoc().getSourceRange());
    return Type();
  }

  // Compute the type of the property to plug in to the delegate type.
  tc.validateDecl(var);
  Type propertyType = var->getType();

  // Form the specialized type.
  Type delegateType = tc.applyUnboundGenericArguments(
      unboundGeneric, nominal, delegateAttr->getLocation(),
      TypeResolution::forContextual(var->getDeclContext()), { propertyType });

  // Make sure no unbound types remain; this could happen if there are outer
  // unbound types that weren't resolved by the application of the property
  // type.
  if (delegateType->hasUnboundGenericType()) {
    ctx.Diags.diagnose(delegateAttr->getLocation(),
                       diag::property_delegate_incompatible_unbound,
                       delegateType)
      .highlight(delegateAttr->getTypeLoc().getSourceRange());
    return Type();
  }

  return delegateType->mapTypeOutOfContext();
}
