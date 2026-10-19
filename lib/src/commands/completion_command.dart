import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';

class CompletionCommand extends BaseCommand {
  CompletionCommand() : super(
    name: 'completion',
    description: 'Generate shell completion scripts',
    usage: '<shell> [options]',
  ) {
    parser.addOption('output', abbr: 'o', help: 'Output file path');
  }
  @override
  Future<void> run(List<String> args, ConfigService config, Logger logger) async {
    final parsedArgs = parser.parse(args);

    if (parsedArgs['help'] as bool) {
      printUsage(logger);
      return;
    }
    final shell = parsedArgs.rest.isNotEmpty ? parsedArgs.rest.first : 'bash';
    final output = parsedArgs['output'] as String?;
    final script = _generateCompletionScript(shell);
    if (output != null) {
      await File(output).writeAsString(script);
      logger.success('Completion script written to $output');
      logger.info('Add to your shell config:');
      _printSetupInstructions(logger, shell, output);
    } else {
      stdout.write(script);
    }
  }

  String _generateCompletionScript(String shell) {
    switch (shell.toLowerCase()) {
      case 'bash':
        return _bashCompletion();
      case 'zsh':
        return _zshCompletion();
      case 'fish':
        return _fishCompletion();
      case 'powershell':
        return _powershellCompletion();
      default:
        throw ArgumentError('Unsupported shell: $shell. Supported: bash, zsh, fish, powershell');
    }
  }

  String _bashCompletion() => '''
# NinjaDev bash completion
_ninjadev_completion() {
  local IFS=\\n
  local response
  response=\$(env COMP_WORDS="\${COMP_WORDS[*]}" COMP_CWORD=\$COMP_CWORD _NINJADEV_COMPLETE=bash_complete ninjadev)
  for completion in \$response; do
    COMPREPLY+=("\$completion")
  done
}
complete -F _ninjadev_completion ninjadev
''';

  String _zshCompletion() => '''
# NinjaDev zsh completion
#compdef ninjadev
_ninjadev() {
  local -a completions
  local -a completions_with_descriptions
  local -a response
  response=(\${(@f)\$(env COMP_WORDS="\${words[*]}" COMP_CWORD=\$CURRENT _NINJADEV_COMPLETE=zsh_complete ninjadev)})
  for key in "\${response[@]}"; do
    if [[ "\$key" == "--"* ]]; then
      completions_with_descriptions+=("\$key")
    else
      completions+=("\$key")
    fi
  done
  if [ -n "\$completions_with_descriptions" ]; then
    _describe -V completions_with_descriptions completions_with_descriptions
  fi
  if [ -n "\$completions" ]; then
    compadd -a completions
  fi
}
compdef _ninjadev ninjadev
''';

  String _fishCompletion() => '''
# NinjaDev fish completion
function __fish_ninjadev_complete
  set -l response (env COMP_WORDS=(commandline -cp) COMP_CWORD=(commandline -opc) _NINJADEV_COMPLETE=fish_complete ninjadev)
  for completion in \$response
    echo \$completion
  end
end
complete -c ninjadev -f -a '(__fish_ninjadev_complete)'
''';

  String _powershellCompletion() => '''
# NinjaDev PowerShell completion
Register-ArgumentCompleter -Native -CommandName ninjadev -ScriptBlock {
  param(\$wordToComplete, \$commandAst, \$cursorPosition)
  \$env:COMP_WORDS = \$commandAst.ToString()
  \$env:COMP_CWORD = \$commandAst.EndOffset
  \$env:_NINJADEV_COMPLETE = 'powershell_complete'
  ninjadev | ForEach-Object { [System.Management.Automation.CompletionResult]::new(\$_, \$_, 'ParameterValue', \$_) }
}
''';

  void _printSetupInstructions(Logger logger, String shell, String output) {
    switch (shell) {
      case 'bash':
        logger.info('  source $output');
        logger.info('  # Or add to ~/.bashrc: echo "source $output" >> ~/.bashrc');
        break;
      case 'zsh':
        logger.info('  source $output');
        logger.info('  # Or add to ~/.zshrc: echo "source $output" >> ~/.zshrc');
        break;
      case 'fish':
        logger.info('  cp $output ~/.config/fish/completions/ninjadev.fish');
        break;
      case 'powershell':
        logger.info('  . $output');
        logger.info('  # Or add to \$PROFILE: echo ". $output" >> \$PROFILE');
        break;
    }
  }
}
