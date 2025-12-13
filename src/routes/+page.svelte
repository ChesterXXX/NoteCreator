<script lang="ts">
	import { onMount } from 'svelte';
	import { invoke } from '@tauri-apps/api/core';
	import { open } from '@tauri-apps/plugin-dialog';
	import { join } from '@tauri-apps/api/path';

	const problemsJson = 'problems.json';
	const assignmentsJson = 'assignments.json';

	interface Problem {
		daynote: number;
		label: string;
		refLabel: string;
		problemType: string;
	}

	interface Assignment {
		name: string;
		date: Date;
		deadline: Date;
		note: string;
		labels: string[];
	}

	let problemsJsonFile = $state('');
	let assignmentsJsonFile = $state('');

	let workingDir = $state('');
	let typstFilePath = $state('');
	let daynotesDir = $state('');
	let assignmentsDir = $state('');

	let problems = $state<Problem[]>([]);
	let filteredProblems = $derived.by(() => {
		return problems.filter((p) => selectedProblemTypes.includes(p.problemType));
	});

	let problemTypes = $state<string[]>([]);
	let selectedProblemTypes = $state<string[]>([]);

	let selectedProblems = $state<Problem[]>([]);

	let assignments = $state<Assignment[]>([]);

	const emptyAssignmet = () => {
		const today = new Date();
		const deadlineDate = new Date(today);
		deadlineDate.setDate(today.getDate() + 7);
		return {
			name: 'Assignment',
			date: today,
			deadline: deadlineDate,
			note: '',
			labels: []
		} as Assignment;
	};

	let selectedAssignment = $state<Assignment>();

	let draftAssignment = $derived.by(() => {
		return structuredClone(selectedAssignment);
	});

	let daynotes = $state<number[]>([]);
	let daynoteCount = $state(0);

	let fancyMode = $state(true);
	let showHints = $state(true);
	let showProofs = $state(true);

	interface Config {
		typst_file_path: string;
		assignment_dir: string;
		daynotes_dir: string;
	}

	let date = $state('');
	let deadline = $state('');
	let assignmentName = $state('');
	let assignmentNote = $state('');

	let currentlyCompilingDaynote = $state(0);

	let loadingAssignments = $state(false);
	let compilingDaynotes = $state(false);
	let loadingLabels = $state(false);
	let editingAssignment = $state(false);
	const isAnyLoading = $derived(
		loadingLabels || compilingDaynotes || loadingAssignments || editingAssignment
	);

	const splitRefLabel = (refLabel: string) => {
		const match = refLabel.match(/^([^-]+)-(.*)$/)!;
		if (!match) {
			return ['unknown', refLabel];
		} else {
			const [, problemType, problemLabel] = match;
			return [problemType, problemLabel];
		}
	};

	const readProblemsJson = async () => {
		if (workingDir) {
			try {
				problemsJsonFile = workingDir + problemsJson;
				const data = await invoke<string>('read_file', { filePath: problemsJsonFile });
				const jsonData: { daynote: number; 'ref-label': string }[] = JSON.parse(data);

				problems = jsonData
					.filter((p) => p['ref-label'] != undefined)
					.map((p) => {
						const [problemType, problemLabel] = splitRefLabel(p['ref-label']);
						return {
							daynote: p.daynote,
							label: problemLabel,
							refLabel: p['ref-label'],
							problemType: problemType
						};
					});

				problemTypes = [...new Set(problems.map((p) => p.problemType))];
				selectedProblemTypes = problemTypes;

				daynotes = jsonData.filter((p) => p['ref-label'] == undefined).map((p) => p.daynote);
				daynoteCount = daynotes.length;

				console.log(`Parsed ${jsonData.length} problems across ${daynoteCount} many daynotes!`);
			} catch (err) {
				console.log('Problems JSON not found or failed to parse ' + err);
			}
		} else {
			console.log('Working directory undetermined.');
		}
	};

	const readAssignmentsJson = async () => {
		if (workingDir) {
			loadingAssignments = true;
			try {
				assignmentsJsonFile = workingDir + assignmentsJson;
				const data = await invoke<string>('read_file', { filePath: assignmentsJsonFile });
				const jsonData = JSON.parse(data);

				assignments = jsonData.map((a: any) => ({
					name: a.name,
					date: new Date(a.date.year, a.date.month, a.date.day),
					deadline: new Date(a.deadline.year, a.deadline.month, a.deadline.day),
					note: a.note,
					labels: a.labels
				}));

				console.log(`Parsed ${assignments.length} assignments!`);
			} catch (err) {
				console.log('Assignments JSON not found or failed to parse ' + err);
			}
			loadingAssignments = false;
		} else {
			console.log('Working directory undetermined.');
		}
	};

	const toggleSelectedProblems = (problem: Problem) => {
		selectedProblems = selectedProblems.includes(problem)
			? selectedProblems.filter((p) => p !== problem)
			: [...selectedProblems, problem];
	};

	const selectAssignment = (assignment: Assignment) => {
		if (!editingAssignment) {
			selectedAssignment = assignment;
			selectedProblems = assignment.labels
				.map((label) => problems.find((p) => p.refLabel === label))
				.filter((p): p is Problem => p !== undefined);
			console.log(selectedAssignment);
		}
	};

	const toggleProblemFilter = (problemType: string) => {
		selectedProblemTypes = selectedProblemTypes.includes(problemType)
			? selectedProblemTypes.filter((t) => t !== problemType)
			: [...selectedProblemTypes, problemType];
	};

	onMount(async () => {
		try {
			const config = await invoke<Config>('read_config');
			typstFilePath = config.typst_file_path;
			if (typstFilePath) {
				workingDir = await invoke<string>('get_parent_dir', { path: typstFilePath });
			}
			assignmentsDir = config.assignment_dir;
			daynotesDir = config.daynotes_dir;
		} catch (err) {
			console.log('Config not found!');
		}
		await readProblemsJson();
		await readAssignmentsJson();
	});

	const selectFile = async () => {
		const selected = await open({
			directory: false,
			multiple: false
		});
		if (selected) {
			typstFilePath = selected;
			workingDir = await invoke<string>('get_parent_dir', { path: selected });
			await saveConfig();
			await readProblemsJson();
		}
	};

	const selectDir = async (field: string) => {
		const selected = await open({
			directory: true,
			multiple: false
		});
		if (selected) {
			if (field === 'assignmentsDir') assignmentsDir = selected;
			if (field === 'daynotesDir') daynotesDir = selected;

			await saveConfig();
		}
	};

	const saveConfig = async () => {
		try {
			await invoke('write_config', {
				config: {
					typst_file_path: typstFilePath,
					assignment_dir: assignmentsDir,
					daynotes_dir: daynotesDir
				}
			});
			console.log('Config saved!');
		} catch (err) {
			console.error('Failed to save config:', err);
		}
	};

	const createDaynotes = async () => {
		compilingDaynotes = true;
		for (const daynote of daynotes) {
			currentlyCompilingDaynote = daynote;
			let outputFile = `daynote${daynote}.pdf`;
			try {
				const args = [
					`fancy-mode=${fancyMode}`,
					`show-hints=${showHints}`,
					`show-proofs=${showProofs}`,
					`daynotes-to-show=(${daynote})`
				];
				const result = await invoke('compile_typst', {
					inputFile: typstFilePath,
					outputFile: await join(daynotesDir, outputFile),
					args: args
				});
				console.log(`Successfully compiled : ${outputFile} ` + result);
			} catch (err) {
				console.error('Error:', err);
			}
		}
		compilingDaynotes = false;
	};

	const handleCreateAssignment = () => {
		// Create assignment logic here
	};
	const loadLabelsFromTypst = async () => {
		loadingLabels = true;
		try {
			const _ = await invoke('query_typst', {
				filePath: typstFilePath,
				outputDir: workingDir
			});
		} catch (err) {
			console.error('Error:', err);
		}
		loadingLabels = false;
	};
</script>

<div class="min-h-screen bg-gray-50 p-8">
	<div class="max-w-6xl mx-auto">
		<div class="flex justify-center">
			<h1 class="text-3xl font-bold flex text-gray-900 mb-8">Note Creator</h1>
		</div>

		<!-- File Paths Section -->
		<div class="bg-white rounded-lg shadow p-6 mb-6">
			<h2 class="text-xl font-semibold text-gray-800 mb-4">Configuration</h2>
			<div class="grid grid-cols-2 gap-4">
				<div>
					<label for="typstFilePath" class="block text-sm font-medium text-gray-700 mb-2"
						>Typst File</label
					>
					<div class="relative">
						<input
							id="typstFilePath"
							type="text"
							bind:value={typstFilePath}
							readonly
							class="w-full px-4 py-2 pr-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						/>
						<button
							onclick={selectFile}
							class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-gray-600 hover:text-blue-500 transition"
							title="Browse files"
						>
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
								/>
							</svg>
						</button>
					</div>
				</div>
				<div>
					<label for="loadLabels" class="block text-sm font-medium text-gray-700 mb-2"
						>Load problem labels and daynotes</label
					>
					<button
						id="loadLabels"
						onclick={loadLabelsFromTypst}
						disabled={isAnyLoading}
						class="px-6 py-2 bg-blue-500 min-w-60 w-full text-white rounded-lg hover:bg-blue-600 transition disabled:bg-gray-400"
					>
						{loadingLabels ? 'Loading labels...' : 'Load problem labels'}
					</button>
				</div>
				<div>
					<label for="assignmentDir" class="block text-sm font-medium text-gray-700 mb-2"
						>Assignment Directory</label
					>
					<div class="relative">
						<input
							id="assignmentDir"
							type="text"
							readonly
							bind:value={assignmentsDir}
							class="w-full px-4 py-2 pr-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						/>
						<button
							onclick={() => selectDir('assignmentsDir')}
							class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-gray-600 hover:text-blue-500 transition"
							title="Browse folders"
						>
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
								/>
							</svg>
						</button>
					</div>
				</div>
				<div>
					<label for="daynotesDir" class="block text-sm font-medium text-gray-700 mb-2"
						>Daynotes Directory</label
					>
					<div class="relative">
						<input
							id="daynotesDir"
							type="text"
							readonly
							bind:value={daynotesDir}
							class="w-full px-4 py-2 pr-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
						/>
						<button
							onclick={() => selectDir('daynotesDir')}
							class="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-gray-600 hover:text-blue-500 transition"
							title="Browse folders"
						>
							<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
								/>
							</svg>
						</button>
					</div>
				</div>
			</div>
		</div>

		<!-- Daynote Compilation -->
		<div class="bg-white rounded-lg shadow p-6 mb-6">
			<h2 class="text-xl font-semibold text-gray-800 mb-4">Create Daynotes</h2>
			<div class="flex justify-around">
				<label class="flex items-center gap-2 cursor-pointer">
					<input type="checkbox" bind:checked={fancyMode} class="h-4 w-4 rounded-sm" />
					<span>Fancy Mode</span>
				</label>

				<label class="flex items-center gap-2 cursor-pointer">
					<input type="checkbox" bind:checked={showHints} class="h-4 w-4 rounded-sm" />
					<span>Show Hints</span>
				</label>

				<label class="flex items-center gap-2 cursor-pointer">
					<input type="checkbox" bind:checked={showProofs} class="h-4 w-4 rounded-sm" />
					<span>Show Proofs</span>
				</label>
			</div>

			<div class="flex gap-3 mt-6 justify-center">
				<button
					onclick={createDaynotes}
					disabled={isAnyLoading || daynoteCount === 0}
					class="px-6 py-2 bg-green-500 min-w-60 text-white rounded-lg hover:bg-green-600 transition disabled:bg-gray-400"
				>
					{#if compilingDaynotes}
						Creating {currentlyCompilingDaynote}/{daynoteCount} daynote
					{:else if daynoteCount > 0}
						Create {daynoteCount}
						{daynoteCount > 1 ? 'daynotes' : 'daynote'}
					{:else}
						No daynotes to create
					{/if}
				</button>
			</div>
		</div>

		<!-- Assignment Creation -->
		<div class="bg-white rounded-lg shadow p-6 mb-6 flex flex-col gap-4">
			<div class="flex items-center p-2">
				<span class="text-xl flex items-center h-10 font-semibold text-gray-800 mr-5"
					>Create Assignments</span
				>
				<button
					type="button"
					onclick={readAssignmentsJson}
					disabled={isAnyLoading}
					class="h-10 bg-red-400 min-w-40 text-white rounded-lg hover:bg-green-600 transition disabled:bg-gray-400"
					aria-label="Load assignments">Load Assignment</button
				>
			</div>
			<div class="flex overflow-x-auto h-30 w-full border border-gray-300 rounded-lg gap-2 p-2">
				{#each assignments as assignment}
					<button
						type="button"
						class="flex flex-col items-center p-2 border-dotted border rounded-lg min-w-40 cursor-pointer gap-1 hover:bg-amber-100"
						class:bg-red-100={assignment === selectedAssignment}
						onclick={() => selectAssignment(assignment)}
					>
						<span>{assignment.name}</span>
						<span class="font-thin text-xs text-green-500"
							>{assignment.date.toLocaleDateString('en-US', {
								month: 'short',
								day: '2-digit',
								year: 'numeric'
							})}</span
						>
						<span class="font-thin text-xs text-red-500"
							>{assignment.deadline.toLocaleDateString('en-US', {
								month: 'short',
								day: '2-digit',
								year: 'numeric'
							})}</span
						>
					</button>
				{/each}
				<div
					class="flex flex-col items-center p-2 border-dotted border rounded-lg min-w-40 cursor-pointer gap-1 hover:bg-amber-100"
				>
					<button
						type="button"
						class="p-1 text-gray-500 w-full h-full flex justify-center hover:text-gray-600 transition"
						aria-label="New"
					>
						<svg
							xmlns="http://www.w3.org/2000/svg"
							viewBox="0 0 24 24"
							fill="currentColor"
							class="h-full"
						>
							<path d="M11 5h2v14h-2zM5 11h14v2H5z" />
						</svg>
					</button>
				</div>
			</div>
			<div class="flex gap-5">
				<div class="flex-1/2">
					<div class="p-2 h-10 flex justify-between">
						<span>Problems ({filteredProblems.length}/{problems.length})</span>
						<div class="flex gap-1">
							{#each problemTypes as problemType}
								<button
									type="button"
									onclick={() => toggleProblemFilter(problemType)}
									class="border-0 hover:bg-gray-400 rounded-sm p-2 flex items-center cursor-pointer"
									class:bg-gray-200={!selectedProblemTypes.includes(problemType)}
									class:bg-blue-300={selectedProblemTypes.includes(problemType)}
								>
									<span class="text-xs"
										>{problemType} ({problems.filter((p) => p.problemType == problemType)
											.length})</span
									>
								</button>
							{/each}
						</div>
					</div>
					<div
						class="h-64 overflow-y-auto w-full flex flex-col border border-gray-300 rounded-lg gap-1 p-1"
					>
						{#each filteredProblems as problem}
							<button
								type="button"
								onclick={() => toggleSelectedProblems(problem)}
								class="flex flex-col p-2 border-dotted border rounded-lg cursor-pointer"
								class:bg-red-100={selectedProblems.includes(problem)}
								class:bg-gray-100={!selectedProblems.includes(problem)}
							>
								<div class="flex justify-between">
									<span class="text-xs font-thin">Daynote: {problem.daynote}</span>
									<span class="text-xs font-thin">Type: {problem.problemType}</span>
								</div>
								<div class="mt-1 flex">
									<span>{problem.label}</span>
								</div>
							</button>
						{/each}
					</div>
				</div>
				<div class="flex-1/2">
					<div class="p-2 h-10">
						<span>Selected problems</span>
					</div>
					<div class="h-64 overflow-y-auto w-full flex flex-col border border-gray-300 rounded-lg">
						{#each selectedProblems as problem}
							<button
								type="button"
								onclick={() => toggleSelectedProblems(problem)}
								class="flex flex-col p-2 border-dotted border rounded-lg cursor-pointer"
								class:bg-red-100={selectedProblems.includes(problem)}
								class:bg-gray-100={!selectedProblems.includes(problem)}
							>
								<div class="flex justify-between">
									<span class="text-xs font-thin">Daynote: {problem.daynote}</span>
									<span class="text-xs font-thin">Type: {problem.problemType}</span>
								</div>
								<div class="mt-1 flex">
									<span>{problem.label}</span>
								</div>
							</button>
						{/each}
					</div>
				</div>
			</div>
		</div>

		<!-- Lists Section -->
		<div class="grid grid-cols-2 gap-6 mb-6">
			<!-- Available Labels -->
			<div class="bg-white rounded-lg shadow p-6">
				<h3 class="text-lg font-semibold text-gray-800 mb-4">
					Problems ({filteredProblems.length}/{problems.length})
				</h3>
				<div class="border border-gray-300 rounded-lg h-64 overflow-y-auto">
					{#if problems.length > 0}
						<ul class="divide-y">
							{#each problems as daynote}
								<!-- {#if daynote[1].length > 0}
									{#each daynote[1] as problem}
										<li>
											<button
												type="button"
												onclick={() => toggleSelectedProblems(problem)}
												class="w-full text-left p-2 flex flex-col focus:outline-none"
												class:bg-gray-200={selectedProblems.includes(problem)}
												class:hover:bg-gray-100={!selectedProblems.includes(problem)}
												class:hover:bg-gray-300={selectedProblems.includes(problem)}
											>
												<span class="text-xs text-gray-400">Daynote {daynote[0]}</span>
												<span>{problem}</span>
											</button>
										</li>
									{/each}
								{/if} -->
							{/each}
						</ul>
					{:else}
						<div class="px-4 py-8 text-center text-gray-400">No problem labels loaded</div>
					{/if}
				</div>
			</div>
		</div>

		<!-- Assignment Form -->
		<div class="bg-white rounded-lg shadow p-6">
			<h2 class="text-xl font-semibold text-gray-800 mb-4">Create Assignment</h2>
			<div class="grid grid-cols-2 gap-4 mb-4">
				<div>
					<label for="date" class="block text-sm font-medium text-gray-700 mb-2">Date</label>
					<input
						id="date"
						type="date"
						value={date}
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>
				<div>
					<label for="deadline" class="block text-sm font-medium text-gray-700 mb-2">Deadline</label
					>
					<input
						id="deadline"
						type="date"
						value={deadline}
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
					/>
				</div>
			</div>

			<div class="mb-4">
				<label for="assignmentName" class="block text-sm font-medium text-gray-700 mb-2"
					>Assignment Name</label
				>
				<input
					type="text"
					value={assignmentName}
					class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
				/>
			</div>

			<div class="mb-6">
				<label for="assignmentNote" class="block text-sm font-medium text-gray-700 mb-2"
					>Assignment Note</label
				>
				<textarea
					id="assignmentNote"
					onchange={(e) => (assignmentNote = e.currentTarget.value)}
					oninput={(e) => (assignmentNote = e.currentTarget.value)}
					rows="4"
					class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500
					focus:border-transparent"
				>
				</textarea>
			</div>

			<button
				onclick={handleCreateAssignment}
				class="px-6 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition"
			>
				Create Assignment
			</button>
		</div>
	</div>
</div>
