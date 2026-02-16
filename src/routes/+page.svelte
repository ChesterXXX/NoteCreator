<script lang="ts">
	import { onMount } from 'svelte';
	import { invoke } from '@tauri-apps/api/core';
	import { open, confirm } from '@tauri-apps/plugin-dialog';
	import { join } from '@tauri-apps/api/path';
	import { migrate } from 'svelte/compiler';
	// import { _ } from '$env/static/private';
	// import { _ } from '$env/static/private';

	const problemsJson = 'problems.json';
	const assignmentsJson = 'assignments.json';

	interface Problem {
		daynote: number;
		shortLabel: string;
		fullLabel: string;
		problemType: string;
	}

	interface Assignment {
		name: string;
		date: Date;
		deadline: Date;
		note: string;
		labels: string[];
	}

	let typstFilePath = $state('');
	let daynotesDir = $state('');
	let assignmentsDir = $state('');

	let workingDir = $state('');
	const computeWorkingDir = async () => {
		if (!typstFilePath) workingDir = '';
		workingDir = await invoke<string>('get_parent_dir', { path: typstFilePath });
	};

	let isTypstFilePathSet = $derived(Boolean(typstFilePath));
	let isDaynotesDirSet = $derived(Boolean(daynotesDir));
	let isAssignmentsDirSet = $derived(Boolean(assignmentsDir));
	let isAllPathSet = $derived(isTypstFilePathSet && isDaynotesDirSet && isAssignmentsDirSet);

	let problemsJsonFile = $derived(workingDir ? workingDir + problemsJson : '');
	let assignmentsJsonFile = $derived(workingDir ? workingDir + assignmentsJson : '');

	let problems = $state<Problem[]>([]);
	let filteredProblems = $derived.by(() => {
		return problems.filter((p) => selectedProblemTypes.includes(p.problemType));
	});

	let problemTypes = $state<string[]>([]);
	let selectedProblemTypes = $state<string[]>([]);

	let selectedProblems = $state<Problem[]>([]);

	let assignments = $state<Assignment[]>([]);

	let creatingNewAssignment = $state(false);

	let assignmentDateString = $state<string>('');
	let assignmentDeadlineString = $state<string>('');
	$effect(() => {
		if (!draftAssignment) {
			assignmentDateString = '';
			assignmentDeadlineString = '';
		} else {
			assignmentDateString = Intl.DateTimeFormat('en-CA').format(draftAssignment.date);
			assignmentDeadlineString = Intl.DateTimeFormat('en-CA').format(draftAssignment.deadline);
		}
	});
	$effect(() => {
		if (!draftAssignment) {
			return;
		} else {
			if (assignmentDateString) {
				const [y, m, d] = assignmentDateString.split('-').map(Number);
				draftAssignment.date = new Date(y, m - 1, d);
			}

			if (assignmentDeadlineString) {
				const [y, m, d] = assignmentDeadlineString.split('-').map(Number);
				draftAssignment.deadline = new Date(y, m - 1, d);
			}
		}
	});

	const emptyAssignment = () => {
		const today = new Date();
		const deadlineDate = new Date(today);
		deadlineDate.setDate(today.getDate() + 7);
		const name = `Assignment ${assignments.length + 1}`;
		return {
			name: name,
			date: today,
			deadline: deadlineDate,
			note: '',
			labels: []
		} as Assignment;
	};

	let selectedAssignmentIndex = $state<number | null>(null);

	let draftAssignment = $state<Assignment>(emptyAssignment());
	$effect(() => {
		if (selectedAssignmentIndex === null) {
			if (editingAssignment) {
				draftAssignment.labels = selectedProblems.map((p) => p.fullLabel);
			}
		} else {
			const selectedAssignment = assignments[selectedAssignmentIndex];
			draftAssignment = {
				...selectedAssignment,
				labels: selectedProblems.map((p) => p.fullLabel)
			};
		}
	});

	const createNewAssignment = () => {
		selectedAssignmentIndex = null;
		selectedProblems = [];
		draftAssignment = emptyAssignment();
		editingAssignment = true;
		creatingNewAssignment = true;
	};

	// the daynote count starts from 1
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

	let currentlyCompilingDaynote = $state(0);
	let currentlyCompilingAssignment = $state(0);

	let loadingAssignments = $state(false);
	let compilingDaynotes = $state(false);
	let loadingLabels = $state(false);
	let editingAssignment = $state(false);
	let compilingAssignment = $state(false);
	let compilingAllAssignments = $state(false);
	const isAnyLoading = $derived(
		loadingLabels ||
			compilingDaynotes ||
			loadingAssignments ||
			compilingAssignment ||
			compilingAllAssignments
	);

	const isAssignmentEdited = () => {
		if (selectedAssignmentIndex === null) {
			return editingAssignment;
		} else {
			const selectedAssignment = assignments[selectedAssignmentIndex];
			return JSON.stringify(draftAssignment) !== JSON.stringify(selectedAssignment);
		}
	};

	const confirmSave = async () => {
		if (editingAssignment) {
			if (isAssignmentEdited()) {
				console.log('Assignment Edited');
				const shouldSave = await confirm('You have unsaved changes. Do you want to save them?', {
					title: 'Unsaved changes',
					okLabel: 'Save',
					cancelLabel: 'Discard'
				});
				editingAssignment = false;
				creatingNewAssignment = false;
				return shouldSave;
			}
		}
	};

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
				const data = await invoke<string>('read_file', { filePath: problemsJsonFile });
				const jsonData: { daynote: number; 'ref-label': string }[] = JSON.parse(data);

				problems = jsonData
					.filter((p) => p['ref-label'] != undefined)
					.map((p) => {
						const [problemType, problemLabel] = splitRefLabel(p['ref-label']);
						return {
							daynote: p.daynote,
							shortLabel: problemLabel,
							fullLabel: p['ref-label'],
							problemType: problemType
						};
					});

				problemTypes = [...new Set(problems.map((p) => p.problemType))];
				selectedProblemTypes = problemTypes;

				daynotes = jsonData.filter((p) => p['ref-label'] == undefined).map((p) => p.daynote);
				daynoteCount = daynotes.length;
				daynoteRange = [...Array(daynoteCount)].map((_, i) => i + 1);

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
			discardAssignment();
		} else {
			console.log('Working directory undetermined.');
		}
	};

	const writeAssignmentsJson = async () => {
		try {
			const jsonAssignments = assignments.map((assignment) => {
				return {
					name: assignment.name,
					date: {
						year: assignment.date.getFullYear(),
						month: assignment.date.getMonth(),
						day: assignment.date.getDate()
					},
					deadline: {
						year: assignment.deadline.getFullYear(),
						month: assignment.deadline.getMonth(),
						day: assignment.deadline.getDate()
					},
					note: assignment.note,
					labels: assignment.labels
				};
			});
			const jsonAssignments2 = assignments.map((assignment) => {
				return {
					...assignment,
					date: {
						year: assignment.date.getFullYear(),
						month: assignment.date.getMonth(),
						day: assignment.date.getDate()
					},
					deadline: {
						year: assignment.deadline.getFullYear(),
						month: assignment.deadline.getMonth(),
						day: assignment.deadline.getDate()
					}
				};
			});
			const jsonData = JSON.stringify(jsonAssignments2);
			const result = await invoke<string>('write_file', {
				filePath: assignmentsJsonFile,
				contents: jsonData
			});
			console.log('Successfully written assignments JSON : ' + result);
		} catch (err) {
			console.log('Error saving assignments to JSON : ' + err);
		}
	};

	const saveAssignment = async () => {
		if (selectedAssignmentIndex === null) {
			if (editingAssignment) {
				assignments.push(draftAssignment);
				selectedAssignmentIndex = assignments.length - 1;
				editingAssignment = false;
				creatingNewAssignment = false;
			}
		} else {
			assignments[selectedAssignmentIndex] = draftAssignment;
		}
		await writeAssignmentsJson();
	};

	const deleteAssignment = async () => {
		assignments = assignments.filter((_, i) => i !== selectedAssignmentIndex);
		discardAssignment();
		await writeAssignmentsJson();
	};

	const discardAssignment = () => {
		draftAssignment = emptyAssignment();
		selectedProblems = [];
		creatingNewAssignment = false;
		editingAssignment = false;
		selectedAssignmentIndex = null;
	};

	let currentlyDraggingIndex: null | number = null;
	let draggingOverIndex: null | number = null;

	const handleDragStart = (e: DragEvent, index: number) => {
		currentlyDraggingIndex = index;
		console.log(`Draggin item ${currentlyDraggingIndex}`);
		if (e.dataTransfer) {
			e.dataTransfer.effectAllowed = 'move';
		}
	};

	const handleDragOver = (e: DragEvent, index: number) => {
		e.preventDefault();
		draggingOverIndex = index;
		console.log(`Draggin over item ${draggingOverIndex}`);
		if (e.dataTransfer) {
			e.dataTransfer.dropEffect = 'move';
		}
	};

	const handleDragLeave = () => {
		console.log('Left drag');
		draggingOverIndex = null;
	};

	const handleDragEnd = () => {
		console.log('Drag ended');
		currentlyDraggingIndex = null;
		draggingOverIndex = null;
	};

	const handleDrop = (e: DragEvent, index: number) => {
		e.preventDefault();
		console.log('Handling drop');
		if (currentlyDraggingIndex !== null && currentlyDraggingIndex !== index) {
			const items = [...selectedProblems];
			const [draggedItem] = items.splice(currentlyDraggingIndex, 1);
			items.splice(index, 0, draggedItem);
			selectedProblems = items;
			console.log('Dragged');
		}
	};

	const toggleSelectedProblems = (problem: Problem) => {
		selectedProblems = selectedProblems.includes(problem)
			? selectedProblems.filter((p) => p !== problem)
			: [...selectedProblems, problem];
	};

	const selectAssignment = async (index: number) => {
		const shouldSave = await confirmSave();
		if (shouldSave) {
			await saveAssignment();
		}
		selectedAssignmentIndex = index;
		editingAssignment = true;
		const selectedAssignment = assignments[index];
		selectedProblems = selectedAssignment.labels
			.map((label) => problems.find((p) => p.fullLabel === label))
			.filter((p): p is Problem => p !== undefined);
		console.log(`Selected ${selectedAssignment.name}`);
	};

	const toggleProblemFilter = (problemType: string) => {
		selectedProblemTypes = selectedProblemTypes.includes(problemType)
			? selectedProblemTypes.filter((t) => t !== problemType)
			: [...selectedProblemTypes, problemType];
	};

	let typstNotPresetnError = $state('');
	const verifyIfTypstInstalled = async () => {
		try {
			await invoke('find_typst');
		} catch (error) {
			typstNotPresetnError = String(error);

			// Auto-dismiss after 5 seconds
			setTimeout(() => {
				typstNotPresetnError = '';
			}, 5000);
		}
	};

	onMount(async () => {
		await verifyIfTypstInstalled();
		try {
			await readConfig();
		} catch (err) {
			console.log('Config not found!' + err);
		}
		try {
			await readProblemsJson();
		} catch (err) {
			console.log('Error reading Problems Json : ' + err);
		}
		try {
			await readAssignmentsJson();
		} catch (err) {
			console.log('Error reading Assignments Json : ' + err);
		}
	});

	const selectFile = async () => {
		const selected = await open({
			directory: false,
			multiple: false
		});
		if (selected) {
			typstFilePath = selected;
			await computeWorkingDir();
			await writeConfig();
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

			await writeConfig();
		}
	};

	const readConfig = async () => {
		const config = await invoke<Config>('read_config');
		typstFilePath = config.typst_file_path;
		await computeWorkingDir();
		assignmentsDir = config.assignment_dir;
		daynotesDir = config.daynotes_dir;
	};

	const writeConfig = async () => {
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

	let rangeInput = $state('');
	let isRangeInputValid = $state(true);
	let daynoteRange = $state<number[]>([]);
	let daynoteRangeCount = $derived(daynoteRange.length);
	const validateRangeInput = (value: string): number[] => {
		const cleaned = value.replace(/\s/g, '');
		if (cleaned === '') {
			isRangeInputValid = true;
			return [...Array(daynoteCount)].map((_, i) => i + 1);
		}

		const validPattern = /^[0-9,\-]+$/;
		if (!validPattern.test(cleaned)) {
			isRangeInputValid = false;
			return [];
		}

		if (
			cleaned.startsWith(',') ||
			cleaned.endsWith(',') ||
			cleaned.includes(',,') ||
			cleaned.includes('--')
		) {
			isRangeInputValid = false;
			return [];
		}

		const numberSet = new Set<number>();
		const parts = cleaned.split(',');
		for (const part of parts) {
			if (part === '') continue;
			if (part.includes('-')) {
				const partRanges = part.split('-');
				if (partRanges.length !== 2) {
					isRangeInputValid = false;
					return [];
				}
				const [start, end] = partRanges;
				if (!/^\d+$/.test(start) || !/^\d+$/.test(end)) {
					isRangeInputValid = false;
					return [];
				}
				const startNum = parseInt(start, 10);
				const endNum = parseInt(end, 10);
				if (startNum > endNum || endNum > daynoteCount) {
					isRangeInputValid = false;
					return [];
				}
				for (let i = startNum; i <= endNum; i++) {
					numberSet.add(i);
				}
			} else {
				if (!/^\d+$/.test(part)) {
					isRangeInputValid = false;
					return [];
				}
				const num = parseInt(part, 10);
				if (num > daynoteCount) {
					isRangeInputValid = false;
					return [];
				}
				numberSet.add(num);
			}
		}
		isRangeInputValid = true;
		return Array.from(numberSet).sort((a, b) => a - b);
	};

	const handleRangeInput = (e: Event) => {
		daynoteRange = validateRangeInput(rangeInput);
	};

	const compileCombinedDaynote = async () => {
		compilingDaynotes = true;
		let outputFile = `daynote_all.pdf`;
		try {
			const args = [
				`fancy-mode=${fancyMode}`,
				`show-hints=${showHints}`,
				`show-proofs=${showProofs}`,
				`daynotes-to-show=(${daynoteRange.join(',')})`
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
		compilingDaynotes = false;
	};

	const compileIndividualDaynotes = async () => {
		compilingDaynotes = true;
		for (const daynote of daynoteRange) {
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

	let showAssignmentCompiledConfirmation = $state(false);
	const compileAssignment = async (assignmentIndex: number | null) => {
		console.log(`Compiling Assignment ${assignmentIndex}`);
		if (assignmentIndex !== null) {
			compilingAssignment = true;
			const selectedAssignment = assignments[assignmentIndex];
			let outputFile = `${selectedAssignment.name}.pdf`;
			try {
				const args = [`assignment-index=${assignmentIndex}`];
				const result = await invoke('compile_typst', {
					inputFile: typstFilePath,
					outputFile: await join(assignmentsDir, outputFile),
					args: args
				});
				console.log(`Successfully compiled ${selectedAssignment.name} : ${outputFile} ` + result);
				showAssignmentCompiledConfirmation = true;
				// await setTimeout(() => {
				// 	showAssignmentCompiledConfirmation = false;
				// }, 500);
				await new Promise((resolve) => setTimeout(resolve, 500));
				showAssignmentCompiledConfirmation = false;
			} catch (err) {
				console.error('Error compiling ${selectedAssignment.name} : ', err);
			}
			compilingAssignment = false;
		}
	};

	const compileAllAssignment = async () => {
		const numAssignments = assignments.length;
		compilingAllAssignments = true;
		for (const [assignmentIndex, selectedAssignment] of assignments.entries()) {
			currentlyCompilingAssignment = assignmentIndex;
			console.log(`Compiling Assignment ${assignmentIndex}`);
			let outputFile = `${selectedAssignment.name}.pdf`;
			try {
				const args = [`assignment-index=${assignmentIndex}`];
				const result = await invoke('compile_typst', {
					inputFile: typstFilePath,
					outputFile: await join(assignmentsDir, outputFile),
					args: args
				});
				console.log(`Successfully compiled ${selectedAssignment.name} : ${outputFile} ` + result);
			} catch (err) {
				console.error('Error compiling ${selectedAssignment.name} : ', err);
			}
		}
		compilingAllAssignments = false;
	};

	const loadLabelsFromTypst = async () => {
		loadingLabels = true;
		try {
			const _ = await invoke('query_typst', {
				filePath: typstFilePath,
				outputDir: workingDir
			});
			await readProblemsJson();
		} catch (err) {
			console.error('Error:', err);
		}
		loadingLabels = false;
	};
</script>

<div class="min-h-screen bg-gray-50 p-8">
	{#if typstNotPresetnError}
		<div
			class="fixed top-4 right-4 max-w-md rounded-lg shadow-lg p-4 bg-red-50 text-red-800 border border-red-200"
		>
			{typstNotPresetnError}
		</div>
	{/if}
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
						disabled={isAnyLoading || !isTypstFilePathSet}
						class="px-6 py-2 bg-blue-500 min-w-60 w-full text-white rounded-lg hover:bg-blue-600 transition disabled:bg-gray-400"
					>
						{loadingLabels ? 'Loading labels...' : 'Load labels'}
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
			<h2 class="text-xl font-semibold text-gray-800 mb-4">Daynotes</h2>
			<div class="flex justify-around">
				<label class="flex items-center gap-2">
					<input
						type="checkbox"
						bind:checked={fancyMode}
						class="h-4 w-4 rounded-sm cursor-pointer disabled:opacity-50 disabled:cursor-default"
						disabled={isAnyLoading || !isAllPathSet}
					/>
					<span>Fancy Mode</span>
				</label>

				<label class="flex items-center gap-2">
					<input
						type="checkbox"
						bind:checked={showHints}
						class="h-4 w-4 rounded-sm cursor-pointer disabled:opacity-50 disabled:cursor-default"
						disabled={isAnyLoading || !isAllPathSet}
					/>
					<span>Show Hints</span>
				</label>

				<label class="flex items-center gap-2">
					<input
						type="checkbox"
						bind:checked={showProofs}
						class="h-4 w-4 rounded-sm cursor-pointer disabled:opacity-50 disabled:cursor-default"
						disabled={isAnyLoading || !isAllPathSet}
					/>
					<span>Show Proofs</span>
				</label>
			</div>

			<div class="flex gap-3 mt-6 justify-center">
				<label for="range-input" class="flex items-center text-sm font-medium text-gray-700 mb-2">
					Range
				</label>
				<input
					id="range-input"
					type="text"
					autocomplete="off"
					bind:value={rangeInput}
					oninput={handleRangeInput}
					disabled={isAnyLoading || !isTypstFilePathSet || !isDaynotesDirSet}
					placeholder="e.g., 1, 3, 5-7, 8"
					class={`w-full px-4 py-2 rounded-lg border-2 transition-colors outline-none
      ${isRangeInputValid ? 'border-gray-300 focus:border-blue-500 bg-white' : 'border-red-500 focus:border-red-600 bg-red-50'}`}
				/>
				<button
					onclick={compileIndividualDaynotes}
					disabled={isAnyLoading ||
						daynoteRangeCount === 0 ||
						!isTypstFilePathSet ||
						!isDaynotesDirSet}
					class="px-6 py-2 bg-green-500 min-w-60 text-white rounded-lg hover:bg-green-600 transition disabled:bg-gray-400"
				>
					{#if compilingDaynotes}
						Creating {currentlyCompilingDaynote}/{daynoteRangeCount} daynote
					{:else if daynoteRangeCount > 0}
						Create {daynoteRangeCount}
						{daynoteRangeCount > 1 ? 'daynotes' : 'daynote'}
					{:else}
						No daynotes to create
					{/if}
				</button>
				<button
					onclick={compileCombinedDaynote}
					disabled={isAnyLoading ||
						daynoteRangeCount === 0 ||
						daynoteRangeCount === 1 ||
						!isTypstFilePathSet ||
						!isDaynotesDirSet}
					class="px-6 py-2 bg-green-500 min-w-60 text-white rounded-lg hover:bg-green-600 transition disabled:bg-gray-400"
				>
					{#if compilingDaynotes}
						Compiling daynotes
					{:else if daynoteRangeCount > 1}
						Create combined daynote
					{:else}
						Nothing to combine
					{/if}
				</button>
			</div>
		</div>

		<!-- Assignment Creation -->
		<div class="bg-white rounded-lg shadow p-6 mb-6 flex flex-col gap-4">
			<div class="flex items-center justify-between p-2">
				<span class="text-xl flex items-center h-10 font-semibold text-gray-800 mr-5"
					>Assignments</span
				>
				<!-- Assignment load, new, compile all buttons -->
				<div class="flex justify-end gap-2">
					<button
						type="button"
						onclick={readAssignmentsJson}
						disabled={isAnyLoading || isAssignmentEdited() || !isAllPathSet}
						class="h-10 bg-red-400 min-w-40 text-white rounded-lg hover:bg-green-600 transition disabled:bg-gray-400"
						aria-label="Load assignments">Load Assignments</button
					>
					<button
						type="button"
						onclick={createNewAssignment}
						disabled={isAnyLoading ||
							creatingNewAssignment ||
							isAssignmentEdited() ||
							!isAllPathSet}
						class="h-10 bg-red-400 min-w-40 text-white rounded-lg hover:bg-green-600 transition disabled:bg-gray-400"
						aria-label="Load assignments">New Assignment</button
					>
					<button
						type="button"
						disabled={isAnyLoading || isAssignmentEdited() || !isAllPathSet}
						onclick={compileAllAssignment}
						class="h-10 bg-green-400 min-w-60 text-white rounded-lg hover:bg-green-600 transition disabled:bg-gray-400"
						aria-label="Load assignments"
					>
						{#if compilingAllAssignments}
							Compiling {currentlyCompilingAssignment}/{assignments.length} assignment
						{:else if daynoteCount > 0}
							Compile {assignments.length}
							{assignments.length > 1 ? 'assignments' : 'assignment'}
						{:else}
							No assignment to compile
						{/if}
					</button>
				</div>
			</div>
			<!-- List of assignments -->
			<div class="flex overflow-x-auto h-30 w-full border border-gray-300 rounded-lg gap-2 p-2">
				{#each assignments as assignment, index}
					<button
						type="button"
						class="flex flex-col items-center p-2 border-dotted border rounded-lg min-w-40 cursor-pointer gap-1 hover:bg-amber-100"
						class:bg-red-100={index === selectedAssignmentIndex}
						onclick={() => selectAssignment(index)}
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
				<!-- Add assignment svg -->
				<div class="flex flex-col items-center p-2 border-dotted border rounded-lg min-w-40 gap-1">
					<button
						type="button"
						onclick={createNewAssignment}
						disabled={creatingNewAssignment || isAnyLoading || !isAllPathSet}
						class="p-1 text-gray-500 w-full h-full flex justify-center hover:text-gray-600 transition cursor-pointer disabled:opacity-50 disabled:hover:bg-none"
						aria-label="New Assignment"
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
			<!-- List of problems -->
			<div class="flex gap-5">
				<!-- All problems -->
				<div class="flex-1/2">
					<div class="p-2 h-10 flex justify-between">
						<span>Problems ({filteredProblems.length}/{problems.length})</span>
						<div class="flex gap-1">
							{#each problemTypes as problemType}
								<button
									type="button"
									onclick={() => toggleProblemFilter(problemType)}
									class="border-0 hover:bg-gray-400 rounded-sm p-1 flex items-center cursor-pointer"
									class:bg-gray-200={!selectedProblemTypes.includes(problemType)}
									class:bg-blue-300={selectedProblemTypes.includes(problemType)}
								>
									<span class="text-[8pt]"
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
									<span>{problem.shortLabel}</span>
								</div>
							</button>
						{/each}
					</div>
				</div>
				<!-- Selected problems -->
				<div class="flex-1/2">
					<div class="p-2 h-10">
						<span>Selected problems</span>
					</div>
					<div class="h-64 overflow-y-auto w-full flex flex-col border border-gray-300 rounded-lg">
						{#each selectedProblems as problem, index}
							<div
								role="button"
								draggable="true"
								ondragstart={(e) => handleDragStart(e, index)}
								ondragover={(e) => handleDragOver(e, index)}
								ondragleave={handleDragLeave}
								ondragend={handleDragEnd}
								ondrop={(e) => handleDrop(e, index)}
								class="flex flex-col p-2 border-dotted border rounded-lg cursor-move"
								aria-label="Selected Problems"
								tabindex="0"
							>
								<div class="flex justify-between">
									<span class="text-xs font-thin">Daynote: {problem.daynote}</span>
									<span class="text-xs font-thin">Type: {problem.problemType}</span>
								</div>
								<div class="mt-1 flex justify-between">
									<span>{problem.shortLabel}</span>
									<button
										onclick={() => toggleSelectedProblems(problem)}
										class="p-2 hover:bg-gray-200 rounded transition-colors cursor-pointer"
										aria-label="Remove Problem"
									>
										<svg
											width="16"
											height="16"
											viewBox="0 0 24 24"
											fill="none"
											stroke="currentColor"
											stroke-width="2"
										>
											<polyline points="3 6 5 6 21 6"></polyline>
											<path
												d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"
											></path>
											<line x1="10" y1="11" x2="10" y2="17"></line>
											<line x1="14" y1="11" x2="14" y2="17"></line>
										</svg>
									</button>
								</div>
							</div>
						{/each}
					</div>
				</div>
			</div>
			<!-- Assignment dates -->
			<div class="grid grid-cols-2 gap-4 mb-4">
				<div>
					<label for="date" class="block text-sm font-medium text-gray-700 mb-2">Date</label>
					<input
						id="date"
						type="date"
						disabled={isAnyLoading || !isAllPathSet}
						bind:value={assignmentDateString}
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
					/>
				</div>
				<div>
					<label for="deadline" class="block text-sm font-medium text-gray-700 mb-2">Deadline</label
					>
					<input
						id="deadline"
						type="date"
						disabled={isAnyLoading || !isAllPathSet}
						bind:value={assignmentDeadlineString}
						class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
					/>
				</div>
			</div>
			<!-- Assignment name -->
			<div class="">
				<label for="assignmentName" class="block text-sm font-medium text-gray-700 mb-2"
					>Assignment Name</label
				>
				<input
					type="text"
					disabled={isAnyLoading || !isAllPathSet}
					bind:value={draftAssignment.name}
					class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
				/>
			</div>
			<!-- Assignment note -->
			<div class="">
				<label for="assignmentNote" class="block text-sm font-medium text-gray-700 mb-2"
					>Assignment Note</label
				>
				<textarea
					id="assignmentNote"
					bind:value={draftAssignment.note}
					rows="4"
					disabled={isAnyLoading || !isAllPathSet}
					class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 disabled:opacity-50 focus:border-transparent"
				>
				</textarea>
			</div>
			<!-- Save and Compile -->
			<div class="flex justify-end gap-5">
				<button
					id="saveAssignment"
					onclick={saveAssignment}
					disabled={!isAssignmentEdited()}
					class="px-6 py-2 bg-blue-500 min-w-60 text-white rounded-lg hover:bg-blue-600 transition disabled:bg-gray-400 cursor-pointer"
				>
					Save Assignment
				</button>
				<button
					id="deleteAssignment"
					onclick={creatingNewAssignment || isAssignmentEdited()
						? discardAssignment
						: deleteAssignment}
					disabled={(!creatingNewAssignment && selectedAssignmentIndex === null) || isAnyLoading}
					class="px-6 py-2 bg-blue-500 min-w-60 text-white rounded-lg hover:bg-blue-600 transition disabled:bg-gray-400 cursor-pointer"
				>
					{creatingNewAssignment
						? 'Discard Assignment'
						: isAssignmentEdited()
							? 'Discard Changes'
							: 'Delete Assignment'}
				</button>
				<button
					id="compileAssignment"
					disabled={selectedAssignmentIndex === null || isAnyLoading || isAssignmentEdited()}
					onclick={() => compileAssignment(selectedAssignmentIndex)}
					class="px-6 py-2 bg-blue-500 min-w-60 text-white rounded-lg hover:bg-blue-600 transition disabled:bg-gray-400 cursor-pointer"
				>
					{#if showAssignmentCompiledConfirmation}
						<span>Done!</span>
					{:else if compilingAssignment}
						<span>Compiling...</span>
					{:else}
						<span>Compile Assignment</span>
					{/if}
				</button>
			</div>
		</div>
	</div>
</div>
