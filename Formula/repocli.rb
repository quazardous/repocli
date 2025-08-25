class Repocli < Formula
  desc "Universal Git hosting provider CLI with GitHub CLI compatibility"
  homepage "https://github.com/quazardous/repocli"
  url "https://github.com/quazardous/repocli/archive/v1.0.0.tar.gz"
  sha256 "your_sha256_hash_here" # This will need to be updated when creating actual releases
  license "MIT"
  head "https://github.com/quazardous/repocli.git", branch: "main"

  depends_on "bash"
  depends_on "jq"

  def install
    bin.install "repocli"
    
    # Install library files
    lib_dir = lib/"repocli"
    lib_dir.install "lib/config.sh"
    lib_dir.install "lib/utils.sh"
    
    # Install provider files
    providers_dir = lib_dir/"providers"
    providers_dir.install "lib/providers/github.sh"
    providers_dir.install "lib/providers/gitlab.sh"
    providers_dir.install "lib/providers/gitea.sh"
    providers_dir.install "lib/providers/codeberg.sh"
    
    # Install documentation
    doc.install "README.md"
    doc.install "CLAUDE.md" if File.exist?("CLAUDE.md")
    doc.install "repocli.conf-example"
  end

  def caveats
    <<~EOS
      REPOCLI is a wrapper around existing Git hosting provider CLIs.
      You'll need to install the CLI tool for your provider:

      GitHub:    brew install gh
      GitLab:    brew install glab
      Gitea:     brew install tea
      
      After installation, run:
        repocli init
      
      Then authenticate with your chosen provider:
        repocli auth login
    EOS
  end

  test do
    assert_match "repocli version", shell_output("#{bin}/repocli --version")
    assert_match "REPOCLI - Universal Git Hosting Provider CLI", shell_output("#{bin}/repocli --help")
  end
end