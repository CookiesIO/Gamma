#if defined _gamma_iterators
 #endinput
#endif
#define _gamma_iterators

/*******************************************************************************
 *	DEFINITIONS
 *******************************************************************************/

enum IteratorType
{
	IteratorType_GameMode,
	IteratorType_BehaviourType,
	IteratorType_Behaviour
}


/*******************************************************************************
 *	LIBRARY FUNCTIONS
 *******************************************************************************/

stock RegisterIteratorNatives()
{
	// Game mode iterator natives
	CreateNative("Gamma_MoreGameModes", Native_Gamma_MoreGameModes);
	CreateNative("Gamma_ReadGameMode", Native_Gamma_ReadGameMode);

	// Behaviour type iterator natives
	CreateNative("Gamma_MoreBehaviourTypes", Native_Gamma_MoreBehaviourTypes);
	CreateNative("Gamma_ReadBehaviourType", Native_Gamma_ReadBehaviourType);

	// Behaviour iterator natives
	CreateNative("Gamma_MoreBehaviours", Native_Gamma_MoreBehaviours);
	CreateNative("Gamma_ReadBehaviour", Native_Gamma_ReadBehaviour);
}


/*******************************************************************************
 *	ITERATOR NATIVES
 *******************************************************************************/

public Native_Gamma_MoreGameModes(Handle:plugin, numParams)
{
	new Handle:iter = Handle:GetNativeCell(1);
	return _:IteratorMoreGameModes(iter);
}

public Native_Gamma_ReadGameMode(Handle:plugin, numParams)
{
	new Handle:iter = Handle:GetNativeCell(1);
	return _:IteratorReadGameMode(iter);
}

public Native_Gamma_MoreBehaviourTypes(Handle:plugin, numParams)
{
	new Handle:iter = Handle:GetNativeCell(1);
	return _:IteratorMoreBehaviourTypes(iter);
}

public Native_Gamma_ReadBehaviourType(Handle:plugin, numParams)
{
	new Handle:iter = Handle:GetNativeCell(1);
	return _:IteratorReadBehaviourType(iter);
}

public Native_Gamma_MoreBehaviours(Handle:plugin, numParams)
{
	new Handle:iter = Handle:GetNativeCell(1);
	return _:IteratorMoreBehaviours(iter);
}

public Native_Gamma_ReadBehaviour(Handle:plugin, numParams)
{
	new Handle:iter = Handle:GetNativeCell(1);
	return _:IteratorReadBehaviour(iter);
}


/*******************************************************************************
 *	ITERATOR FUNCTIONS
 *******************************************************************************/

 // Creates an iterator for an array
stock Handle:CreateIterator(Handle:array, IteratorType:iterType)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, iterType);

	// Throw in all the items in the array to the pack
	new size = GetArraySize(array);
	for (new i = 0; i < size; i++)
	{
		WritePackCell(pack, GetArrayCell(array, i));
	}

	// Advance to the first actual item
	ResetPack(pack);
	ReadPackCell(pack);

	return pack;
}

// Reads the current game mode and advances to the next
stock IteratorRead(Handle:iter, IteratorType:iterExpectedType)
{
	// Get's the current pack position, as we'll be hopping around like bunnies (or something)
	new packPosition = GetPackPosition(iter);

	ResetPack(iter);
	new IteratorType:iterType = ReadPackCell(iter);
	SetPackPosition(iter, packPosition);

	// We gotta need ta be the expected type, rhye
	if (iterType != iterExpectedType)
	{
		ThrowError("Iterator type (%d) is not of the expected type (%d)", iterType, iterExpectedType);
		return 0;
	}

	// Can we still read from the pack? If not return 0
	if (!IsPackReadable(iter, 1))
	{
		return 0;
	}

	return ReadPackCell(iter);
}

// Checks if there's more game modes in the iterator
stock bool:IteratorMore(Handle:iter, IteratorType:iterExpectedType)
{
	// Get's the current pack position, as we'll be hopping around like bunnies (or something)
	new packPosition = GetPackPosition(iter);

	ResetPack(iter);
	new IteratorType:iterType = ReadPackCell(iter);
	SetPackPosition(iter, packPosition);

	// We gotta need ta be the expected type, rhye
	if (iterType != iterExpectedType)
	{
		ThrowError("Iterator type (%d) is not of the expected type (%d)", iterType, iterExpectedType);
		return false;
	}

	// Can we still read from the pack? If not return false
	if (!IsPackReadable(iter, 1))
	{
		return false;
	}
	return true;
}



// Creates a game mode iterator for an array of game modes
stock Handle:CreateGameModeIterator(Handle:gameModes)
{
	return CreateIterator(gameModes, IteratorType_GameMode);
}

// Reads the current game mode and advances to the next
stock GameMode:IteratorReadGameMode(Handle:iter)
{
	return GameMode:IteratorRead(iter, IteratorType_GameMode);
}

// Checks if there's more game modes in the iterator
stock bool:IteratorMoreGameModes(Handle:iter)
{
	return IteratorMore(iter, IteratorType_GameMode);
}



// Creates a behaviour iterator for an array of behaviours
stock Handle:CreateBehaviourTypeIterator(Handle:behaviourTypes)
{
	return CreateIterator(behaviourTypes, IteratorType_BehaviourType);
}

// Reads the current behaviour and advances to the next
stock Behaviour:IteratorReadBehaviourType(Handle:iter)
{
	return Behaviour:IteratorRead(iter, IteratorType_BehaviourType);
}

// Checks if there's more behaviours in the iterator
stock bool:IteratorMoreBehaviourTypes(Handle:iter)
{
	return IteratorMore(iter, IteratorType_BehaviourType);
}



// Creates a behaviour iterator for an array of behaviours
stock Handle:CreateBehaviourIterator(Handle:behaviours)
{
	return CreateIterator(behaviours, IteratorType_Behaviour);
}

// Reads the current behaviour and advances to the next
stock Behaviour:IteratorReadBehaviour(Handle:iter)
{
	return Behaviour:IteratorRead(iter, IteratorType_Behaviour);
}

// Checks if there's more behaviours in the iterator
stock bool:IteratorMoreBehaviours(Handle:iter)
{
	return IteratorMore(iter, IteratorType_Behaviour);
}