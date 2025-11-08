# Contributing to Deploy Ghost on GCP

Thank you for your interest in contributing to Deploy Ghost on GCP! This document provides guidelines and instructions for contributing.

## How to Contribute

### Reporting Issues

If you encounter a bug or have a feature request:

1. **Search existing issues** to avoid duplicates
2. **Create a new issue** with a clear title and description
3. **Include relevant details**:
   - Your operating system and version
   - GCP region and resource configurations
   - Error messages and logs
   - Steps to reproduce the issue
   - Expected vs actual behavior

### Suggesting Enhancements

We welcome suggestions for improvements! Please:

1. Check if the enhancement has already been suggested
2. Create an issue with the `enhancement` label
3. Clearly describe the feature and its benefits
4. Provide examples of how it would be used

### Pull Requests

We love pull requests! Here's how to submit one:

1. **Fork the repository** and create your branch from `main`
2. **Make your changes**:
   - Follow existing code style and conventions
   - Update documentation if needed
   - Test your changes thoroughly
3. **Commit your changes** with clear, descriptive messages
4. **Push to your fork** and submit a pull request
5. **Wait for review** - we'll provide feedback or merge your changes

#### Pull Request Guidelines

- **One feature per PR** - keep changes focused and atomic
- **Update README** if you change functionality
- **Test your changes** in a real GCP environment if possible
- **Follow the existing structure** and patterns
- **Document new features** or configuration options

### Development Setup

To work on this project locally:

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/deploy-ghost-on-gcp.git
cd deploy-ghost-on-gcp

# Create a branch for your feature
git checkout -b feature/your-feature-name

# Make your changes and test them
# ...

# Commit and push
git add .
git commit -m "Add your descriptive commit message"
git push origin feature/your-feature-name
```

### Testing

Before submitting a PR, please test your changes:

1. **Terraform validation**: Run `terraform validate` and `terraform fmt`
2. **Shell scripts**: Test scripts on your platform (macOS/Linux)
3. **Docker**: Build the Docker image successfully
4. **End-to-end**: If possible, deploy to a test GCP project

### Code Style

- **Terraform**: Follow [HashiCorp's style guide](https://www.terraform.io/language/syntax/style)
- **Shell scripts**: Use shellcheck for linting
- **Markdown**: Use clear, concise language with proper formatting
- **Comments**: Add comments for complex logic

### Documentation

Good documentation helps everyone! When contributing:

- Update README.md for user-facing changes
- Add inline comments for complex code
- Include examples for new features
- Keep instructions clear and beginner-friendly

### Community Guidelines

- Be respectful and inclusive
- Help others learn and grow
- Provide constructive feedback
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md) (if applicable)

## Questions?

If you have questions about contributing:

- Open an issue with the `question` label
- Check existing issues and discussions
- Reach out to the maintainer

## Recognition

Contributors will be recognized in our README and release notes. Thank you for helping make this project better!

---

**Happy Contributing! 🎉**
