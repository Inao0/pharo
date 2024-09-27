"
ParseTreeSearcher walks over a normal source code parse tree using the visitor pattern and then matches these nodes against the meta-nodes using the match:inContext: methods defined for the meta-nodes.

Instance Variables:
	answer	<Object>	the ""answer"" that is propagated between matches
	argumentSearches	<Collection of: (Association key: ASTProgramNode value: BlockClosure)>	argument searches (search for the ASTProgramNode and perform the BlockClosure when its found)
	context	<RBSmallDictionary>	a dictionary that contains what each meta-node matches against. This could be a normal Dictionary that is created for each search but is created once and reused (efficiency).
	messages	<Collection>	the sent messages in our searches
	searches	<Collection of: (Association key: ASTProgramNode value: BlockClosure)>	non-argument searches (search for the ASTProgramNode and perform the BlockClosure when its found)
	
***********************
		
""
	New comments: These comments are added in order to understand more how the ASTParseTreeSearcher is working in Pharo, in addition of what special characters we can use to define the patterns we want to match.	
""

A- Instance side:
	-	context
		dictionary: contains the matched patterns
	-	searches
		Ordered collection: contains all the rules like ArgumentRule, MethodRule, TreeRule, Rule ...
	-	argumentSearches
		Ordered collection: filled when addArgumentRule or addArgumentRules is called
	-	matches:do: 
		looks for matches and if match found 
		--> the block in do is executed
		--> a new rule is added to the list of rules 'searches'
	-	executeTree
		-	Executes the tree
		-	Fills context when successful match ???
	-	addRule:
		add rules to the to searches
	-	addRules:
		add multiple rules to searches
	-	addArgumentSearches:
		adds arguments to argumentSearches collection
	-	messages
		returns the list of messages found in a match
	-	hasRules
		returns searches list.
		
B- Patterns:		 

In order to unserstand more how pattern matching work, you can refer to the below description:
Supported charcters are listed below:

	1- Backtick: `
			--> Type: Recurse into
			--> Description: Whenever a match is found, look inside the matched NODE for more matches.
	2- Arobase: @
			--> Type: list
			--> Description: First position matching, list with O or more elements
				* When applied to a variable node --> it will match a literal, variable or a sequence of messages sent to a literal or variable
				* When applied to a keyword message --> it will match a list of keyword messages
				* When applied with a statement character --> Il will match a list of statements.
	3- 	Dot: .
			--> Type: Statement
			--> Description: matches a statement in a sequence node
	4- Hash: #
			--> Type: Literal
			--> Description: maches only literal Objects
		
"
Class {
	#name : 'ASTParseTreeSearcher',
	#superclass : 'ASTProgramNodeVisitor',
	#instVars : [
		'searches',
		'answer',
		'argumentSearches',
		'context',
		'messages'
	],
	#category : 'AST-Core-Matching',
	#package : 'AST-Core',
	#tag : 'Matching'
}

{ #category : 'private' }
ASTParseTreeSearcher class >> buildSelectorString: aSelector [
	| stream keywords |
	aSelector numArgs = 0 ifTrue: [^aSelector].
	stream := String new writeStream.
	keywords := aSelector keywords.
	1 to: keywords size
		do:
			[:i |
			stream
				nextPutAll: (keywords at: i);
				nextPutAll: ' ``@arg';
				nextPutAll: i printString;
				nextPut: $ ].
	^stream contents
]

{ #category : 'private' }
ASTParseTreeSearcher class >> buildSelectorTree: aSelector [
	aSelector isEmpty ifTrue: [^nil].
	^RBParser parseRewriteExpression: '``@receiver '
				, (self buildSelectorString: aSelector)
		onError: [:err :pos | ^nil]
]

{ #category : 'private' }
ASTParseTreeSearcher class >> buildTree: aString method: aBoolean [
	^aBoolean
		ifTrue: [RBParser parseRewriteMethod: aString]
		ifFalse: [RBParser parseRewriteExpression: aString]
]

{ #category : 'instance creation' }
ASTParseTreeSearcher class >> getterMethod: aVarName [
	^ self new
		matchesMethod: '`method ^' , aVarName do: [:aNode :ans | aNode selector];
		matchesMethod: '`method ^' , aVarName, ' ifNil:[ `@expr]' do: [:aNode :ans | aNode selector];
		yourself
]

{ #category : 'instance creation' }
ASTParseTreeSearcher class >> justSendsSuper [
	^ self new
		matchesAnyMethodOf: #(
			'`@method: `@args ^ super `@method: `@args'
			'`@method: `@args super `@method: `@args')
		do: [ :node :answer | true ];
		yourself
]

{ #category : 'instance creation' }
ASTParseTreeSearcher class >> returnSetterMethod: aVarName [
	^(self new)
		matchesMethod: '`method: `Arg ^' , aVarName , ' := `Arg'
			do: [:aNode :ans | aNode selector];
		yourself
]

{ #category : 'instance creation' }
ASTParseTreeSearcher class >> setterMethod: aVarName [
	^(self new)
		matchesAnyMethodOf: (Array with: '`method: `Arg ' , aVarName , ' := `Arg'
					with: '`method: `Arg ^' , aVarName , ' := `Arg')
			do: [:aNode :ans | aNode selector];
		yourself
]

{ #category : 'accessing' }
ASTParseTreeSearcher class >> treeMatching: aString in: aParseTree [
	self new
		matches: aString do: [:aNode :answer | ^aNode];
		executeTree: aParseTree.
	^nil
]

{ #category : 'accessing' }
ASTParseTreeSearcher class >> treeMatchingStatements: subtreeSourceString in: aParseTree [
	| notifier subtree |
	notifier := self new.
	subtree := RBParser parseExpression: subtreeSourceString.
	subtree isSequence
		ifFalse: [subtree := ASTSequenceNode statements: (Array with: subtree)].
	subtree temporaries: (Array with: (ASTPatternVariableNode named: '`@temps')).
	subtree addNodeFirst: (ASTPatternVariableNode named: '`@.S1').
	subtree lastIsReturn
		ifFalse: [subtree addNode: (ASTPatternVariableNode named: '`@.S2')].
	notifier matchesTree: subtree
		do: [:aNode :answer |
				| sub | 
				sub := RBParser parseExpression: subtreeSourceString.
				sub parent: aNode parent. 
				^ sub].
	notifier executeTree: aParseTree.
	^nil
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> addArgumentRule: aParseTreeRule [
	argumentSearches add: aParseTreeRule.
	aParseTreeRule owner: self
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> addArgumentRules: ruleCollection [
	ruleCollection do: [:each | self addArgumentRule: each]
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> addRule: aParseTreeRule [
	searches add: aParseTreeRule.
	aParseTreeRule owner: self
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> addRules: ruleCollection [
	ruleCollection do: [:each | self addRule: each]
]

{ #category : 'search' }
ASTParseTreeSearcher >> addSearch: anAssociation [
	"Create a search rule whose pattern is the association key and action is the association value."

	self matches: anAssociation key do: anAssociation value
]

{ #category : 'search' }
ASTParseTreeSearcher >> addSearches: aCollectionOfAssociations [
	"Defines matching rules based on the list of Association (pattern * action)."

	aCollectionOfAssociations do: [ :each | self addSearch: each ]
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> answer [
	^answer
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> answer: anObject [
	answer := anObject
]

{ #category : 'testing' }
ASTParseTreeSearcher >> canMatchMethod: aCompiledMethod [
	| actualMessages |
	self messages isEmpty
		ifTrue: [ ^ true ].
	actualMessages := aCompiledMethod messages.
	^ self messages
		anySatisfy: [ :each | actualMessages includes: each ]
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> context [
	^context
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> executeMethod: aParseTree initialAnswer: anObject [
	answer := anObject.
	searches detect: [:each | (each performOn: aParseTree) isNotNil] ifNone: [].
	^answer
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> executeTree: aParseTree [
	"Save our current context, in case someone is performing another search inside a match."

	| oldContext |
	oldContext := context.
	context := SmallDictionary new.
	self visitNode: aParseTree.
	context := oldContext.
	^answer
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> executeTree: aParseTree initialAnswer: aValue [
	answer := aValue.
	^self executeTree: aParseTree
]

{ #category : 'private' }
ASTParseTreeSearcher >> foundMatch [
]

{ #category : 'testing' }
ASTParseTreeSearcher >> hasRules [
	^searches notEmpty
]

{ #category : 'initialization' }
ASTParseTreeSearcher >> initialize [
	super initialize.
	context := SmallDictionary new.
	searches := OrderedCollection new.
	argumentSearches := OrderedCollection new: 0
]

{ #category : 'private' }
ASTParseTreeSearcher >> lookForMoreMatchesInContext: oldContext [
	oldContext keysAndValuesDo:
			[:key :value |
			(key isString not and: [key recurseInto])
				ifTrue: [value do: [:each | self visitNode: each]]]
]

{ #category : 'searching' }
ASTParseTreeSearcher >> matches: aPatternedString do: aBlock [
	"Configure the receiver to execute the block when the pattern will match a tree during the actual matching phase (see method executeTree:). A better name for this method could be ifMatches:do:.
	aPattern can be any tree with patterns: '`@x' or '{ `@x . `@m}"
	self addRule: (ASTSearchRule searchFor: aPatternedString thenDo: aBlock)
]

{ #category : 'searching' }
ASTParseTreeSearcher >> matchesAnyArgumentOf: stringCollection do: aBlock [
	stringCollection do: [:each | self matchesArgument: each do: aBlock]
]

{ #category : 'searching' }
ASTParseTreeSearcher >> matchesAnyMethodOf: aStringCollection do: aBlock [
	aStringCollection do: [:each | self matchesMethod: each do: aBlock]
]

{ #category : 'searching' }
ASTParseTreeSearcher >> matchesAnyOf: aStringCollection do: aBlock [
	aStringCollection do: [:each | self matches: each do: aBlock]
]

{ #category : 'searching' }
ASTParseTreeSearcher >> matchesAnyTreeOf: treeCollection do: aBlock [
	treeCollection do: [:each | self matchesTree: each do: aBlock]
]

{ #category : 'searching' }
ASTParseTreeSearcher >> matchesArgument: aString do: aBlock [

	self addArgumentRule: (ASTSearchRule searchFor: aString thenDo: aBlock)
]

{ #category : 'searching' }
ASTParseTreeSearcher >> matchesArgumentTree: aBRProgramNode do: aBlock [
	self
		addArgumentRule: (ASTSearchRule searchForTree: aBRProgramNode thenDo: aBlock)
]

{ #category : 'searching' }
ASTParseTreeSearcher >> matchesMethod: aString do: aBlock [
	self addRule: (ASTSearchRule searchForMethod: aString thenDo: aBlock)
]

{ #category : 'searching' }
ASTParseTreeSearcher >> matchesTree: aBRProgramNode do: aBlock [
	self addRule: (ASTSearchRule searchForTree: aBRProgramNode thenDo: aBlock)
]

{ #category : 'accessing' }
ASTParseTreeSearcher >> messages [
	messages ifNotNil: [^messages].
	argumentSearches notEmpty ifTrue: [^messages := #()].
	messages := Set new.
	searches do:
			[:each |
			| searchMessages |
			searchMessages := each sentMessages.
			ASTProgramNode optimizedSelectors
				do: [:sel | searchMessages remove: sel ifAbsent: []].
			searchMessages isEmpty ifTrue: [^messages := #()].
			messages addAll: searchMessages].
	^messages := messages asArray
]

{ #category : 'private' }
ASTParseTreeSearcher >> performSearches: aSearchCollection on: aNode [
	| value |
	aSearchCollection do: [ :aSearchRule|
		value := aSearchRule performOn: aNode.
		value ifNotNil:
				[self foundMatch.
				^value]].
	^nil
]

{ #category : 'private' }
ASTParseTreeSearcher >> recusivelySearchInContext [
	"We need to save the matched context since the other searches might overwrite it."

	| oldContext |
	oldContext := context.
	context := SmallDictionary new.
	self lookForMoreMatchesInContext: oldContext.
	context := oldContext
]

{ #category : 'accessing - context' }
ASTParseTreeSearcher >> variableNamed: aString [

	^ (context associations detect: [ :assoc | assoc key name = aString  ]) value
]

{ #category : 'visiting' }
ASTParseTreeSearcher >> visitArgumentNode: aNode [
	| value |
	value := self performSearches: argumentSearches on: aNode.
	^ value
		ifNil: [
			super visitArgumentNode: aNode.
			aNode ]
		ifNotNil: [ value ]
]

{ #category : 'visiting' }
ASTParseTreeSearcher >> visitNode: aNode [
	| value |
	value := self performSearches: searches on: aNode.
	^ value
		ifNil: [
			super visitNode: aNode.
			aNode ]
		ifNotNil: [ value ]
]