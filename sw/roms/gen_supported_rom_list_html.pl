open INFILE, "supported_rom_list.txt";

my $supported_rom_cnt = 0;

while (my $rom_name = <INFILE>)
{
  my $top_img_id = <INFILE>;
  my $front_img_id = <INFILE>;

  chop $rom_name;
  chop $top_img_id;
  chop $front_img_id;

  print "<img src=\"http://bootgod.dyndns.org:7777/imagegen.php?ImageID=$top_img_id&width=175\"";
  print "onmouseover=\"this.src=\'http://bootgod.dyndns.org:7777/imagegen.php?ImageID=$front_img_id&width=175\'\"";
  print "onmouseout=\"this.src=\'http://bootgod.dyndns.org:7777/imagegen.php?ImageID=$top_img_id&width=175\'\"";
  print "alt=\"$rom_name\"/>\n\n";

  $supported_rom_cnt++;
}

print "<p><b>$supported_rom_cnt Total Titles</b></p>\n";

